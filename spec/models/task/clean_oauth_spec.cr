require "../../../src/models/task/clean_oauth"

require "../../spec_helper/base"
require "../../spec_helper/factory"

# redefine private methods as public for testing
class Task::CleanOauth
  def cleanup_expired_tokens
    previous_def
  end

  def cleanup_orphaned_clients
    previous_def
  end
end

Spectator.describe Task::CleanOauth do
  setup_spec

  describe "#cleanup_expired_tokens" do
    let_create!(account)
    let_create!(oauth2_provider_client, named: client)

    context "when expired tokens exist" do
      let_create!(
        oauth2_provider_access_token,
        named: expired_token,
        client: client,
        account: account,
        token: "expired_token",
        expires_at: 1.day.ago
      )
      let_create!(
        oauth2_provider_access_token,
        named: valid_token,
        client: client,
        account: account,
        token: "valid_token",
        expires_at: 1.day.from_now
      )

      it "deletes expired access tokens" do
        result = subject.cleanup_expired_tokens
        expect(result).to eq(1)

        remaining_tokens = OAuth2::Provider::AccessToken.all
        expect(remaining_tokens).to contain_exactly(valid_token)
      end
    end
  end

  describe "#cleanup_orphaned_clients" do
    let_create!(account)

    context "when orphaned clients exist" do
      let_create!(
        oauth2_provider_client,
        named: orphaned_client,
        client_name: "Orphaned Client"
      )
      let_create!(
        oauth2_provider_client,
        named: active_client,
        client_name: "Active Client"
      )
      let_create!(
        oauth2_provider_access_token,
        named: expired_token,
        client: orphaned_client,
        account: account,
        token: "expired_token",
        expires_at: 1.day.ago
      )
      let_create!(
        oauth2_provider_access_token,
        named: valid_token,
        client: active_client,
        account: account,
        token: "valid_token",
        expires_at: 1.day.from_now
      )

      it "deletes clients with no active tokens" do
        result = subject.cleanup_orphaned_clients
        expect(result).to eq(1)

        remaining_clients = OAuth2::Provider::Client.all
        expect(remaining_clients).to contain_exactly(active_client)
      end
    end

    context "when recently created clients have no tokens" do
      let_create!(
        oauth2_provider_client,
        named: recent_client,
        client_name: "Recent Client",
        created_at: 30.minutes.ago
      )
      let_create!(
        oauth2_provider_client,
        named: old_client,
        client_name: "Old Client",
        created_at: 2.hours.ago
      )

      it "preserves recent clients but deletes old client" do
        result = subject.cleanup_orphaned_clients
        expect(result).to eq(1)

        remaining_clients = OAuth2::Provider::Client.all
        expect(remaining_clients).to contain_exactly(recent_client)
      end
    end
  end
end
