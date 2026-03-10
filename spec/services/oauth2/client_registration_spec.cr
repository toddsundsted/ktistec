require "../../../src/services/oauth2/client_registration"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe OAuth2::ClientRegistration do
  setup_spec

  before_each do
    OAuth2::ClientRegistration.provisional_clients.clear
  end

  macro register_client(*args)
    described_class.register({{args.splat}})
  end

  describe ".register" do
    context "with valid parameters" do
      subject { register_client("Test App", ["https://example.com/callback"]) }

      let(success) { subject.as(OAuth2::ClientRegistration::Success) }

      it "succeeds" do
        expect(subject).to be_a(OAuth2::ClientRegistration::Success)
      end

      it "generates a client_id" do
        expect(success.client.client_id).not_to be_empty
      end

      it "generates a client_secret" do
        expect(success.client.client_secret).not_to be_empty
      end

      it "defaults scopes to 'read'" do
        expect(success.client.scope).to eq("read")
      end

      let(found) { OAuth2::ClientRegistration.find(success.client.client_id) }

      it "stores client" do
        expect(found).not_to be_nil
      end
    end

    context "with custom scopes" do
      subject { register_client("Test App", ["https://example.com/callback"], "read write follow") }

      it "uses provided scopes" do
        expect(subject.as(OAuth2::ClientRegistration::Success).client.scope).to eq("read write follow")
      end
    end

    context "with blank client_name" do
      subject { register_client("", ["https://example.com/callback"]) }

      let(failure) { subject.as(OAuth2::ClientRegistration::Failure) }

      it "fails" do
        expect(subject).to be_a(OAuth2::ClientRegistration::Failure)
      end

      it "identifies client_name in error" do
        expect(failure.error).to contain("client_name")
      end
    end

    context "with empty redirect_uris" do
      subject { register_client("Test App", [] of String) }

      let(failure) { subject.as(OAuth2::ClientRegistration::Failure) }

      it "fails" do
        expect(subject).to be_a(OAuth2::ClientRegistration::Failure)
      end

      it "identifies redirect_uri in error" do
        expect(failure.error).to contain("redirect_uri")
      end
    end

    context "with redirect_uri missing scheme" do
      subject { register_client("Test App", ["example.com/callback"]) }

      let(failure) { subject.as(OAuth2::ClientRegistration::Failure) }

      it "fails" do
        expect(subject).to be_a(OAuth2::ClientRegistration::Failure)
      end

      it "identifies redirect_uri in error" do
        expect(failure.error).to contain("redirect_uri")
      end
    end

    context "with redirect_uri missing host" do
      subject { register_client("Test App", ["file:///path/to/file"]) }

      let(failure) { subject.as(OAuth2::ClientRegistration::Failure) }

      it "fails" do
        expect(subject).to be_a(OAuth2::ClientRegistration::Failure)
      end

      it "identifies redirect_uri in error" do
        expect(failure.error).to contain("redirect_uri")
      end
    end

    context "with OOB redirect_uri" do
      subject { register_client("Test App", ["urn:ietf:wg:oauth:2.0:oob"]) }

      it "succeeds" do
        expect(subject).to be_a(OAuth2::ClientRegistration::Success)
      end
    end

    context "buffer management" do
      around_each do |example|
        saved_size = OAuth2::ClientRegistration.buffer_size
        OAuth2::ClientRegistration.buffer_size = 3
        example.call
        OAuth2::ClientRegistration.buffer_size = saved_size
      end

      it "evicts oldest client when buffer is full" do
        result1 = register_client("App 1", ["https://example.com/callback"])
        client1_id = result1.as(OAuth2::ClientRegistration::Success).client.client_id

        register_client("App 2", ["https://example.com/callback"])
        register_client("App 3", ["https://example.com/callback"])

        result4 = register_client("App 4", ["https://example.com/callback"])
        client4_id = result4.as(OAuth2::ClientRegistration::Success).client.client_id

        expect(OAuth2::ClientRegistration.find(client1_id)).to be_nil
        expect(OAuth2::ClientRegistration.find(client4_id)).not_to be_nil
      end
    end
  end

  describe ".find" do
    it "returns nil" do
      found = OAuth2::ClientRegistration.find("nonexistent-client-id")
      expect(found).to be_nil
    end

    context "when client exists in database" do
      let_create!(:oauth2_provider_client, client_id: "db-client-id")

      it "returns client" do
        found = OAuth2::ClientRegistration.find("db-client-id")
        expect(found.not_nil!.client_id).to eq("db-client-id")
      end
    end

    context "when client exists in buffer" do
      let!(result) { register_client("Test App", ["https://example.com/callback"]) }

      it "returns client" do
        client_id = result.as(OAuth2::ClientRegistration::Success).client.client_id
        found = OAuth2::ClientRegistration.find(client_id)
        expect(found.not_nil!.client_id).to eq(client_id)
      end
    end
  end

  describe ".persist" do
    subject { register_client("Test App", ["https://example.com/callback"]) }

    let(client) { subject.as(OAuth2::ClientRegistration::Success).client }

    it "returns client" do
      persisted = OAuth2::ClientRegistration.persist(client)
      expect(persisted).to eq(client)
    end

    it "saves client to database" do
      expect { OAuth2::ClientRegistration.persist(client) }
        .to change { OAuth2::Provider::Client.find?(client_id: client.client_id) }.from(nil).to(client)
    end

    context "when client is already persisted" do
      before_each { OAuth2::ClientRegistration.persist(client) }

      it "does not raise error" do
        expect { OAuth2::ClientRegistration.persist(client) }.not_to raise_error
      end
    end
  end

  describe ".remove_provisional" do
    subject { register_client("Test App", ["https://example.com/callback"]) }

    let(client) { subject.as(OAuth2::ClientRegistration::Success).client }

    it "returns nil" do
      result = OAuth2::ClientRegistration.remove_provisional(client)
      expect(result).to be_nil
    end

    it "does not save client to database" do
      expect { OAuth2::ClientRegistration.remove_provisional(client) }
        .not_to change { OAuth2::Provider::Client.find?(client_id: client.client_id) }
    end

    it "removes client from provisional buffer" do
      expect { OAuth2::ClientRegistration.remove_provisional(client) }
        .to change { OAuth2::ClientRegistration.find(client.client_id) }.from(client).to(nil)
    end
  end
end
