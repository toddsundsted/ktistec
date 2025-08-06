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

    context "with a client that has never been accessed" do
      let_create!(
        oauth2_provider_client,
        named: has_been_accessed,
        client_name: "Has Been Accessed",
        last_accessed_at: 1.week.ago,
        created_at: 2.months.ago,
      )
      let_create!(
        oauth2_provider_client,
        named: never_been_accessed,
        client_name: "Never Been Accessed",
        last_accessed_at: nil,
        created_at: 2.months.ago,
      )

      it "deletes the client that has never been accessed" do
        result = subject.cleanup_orphaned_clients
        expect(result).to eq(1)

        remaining_clients = OAuth2::Provider::Client.all
        expect(remaining_clients).to contain_exactly(has_been_accessed)
      end
    end

    context "with a client that was accessed more than four months ago" do
      let_create!(
        oauth2_provider_client,
        named: accessed_recently,
        client_name: "Accessed Recently",
        last_accessed_at: 1.week.ago,
        created_at: 2.months.ago,
      )
      let_create!(
        oauth2_provider_client,
        named: not_accessed_recently,
        client_name: "Not Accessed Recently",
        last_accessed_at: 6.months.ago,
        created_at: 2.months.ago,
      )

      it "deletes the client that has not been accessed recently" do
        result = subject.cleanup_orphaned_clients
        expect(result).to eq(1)

        remaining_clients = OAuth2::Provider::Client.all
        expect(remaining_clients).to contain_exactly(accessed_recently)
      end

    end
  end
end
