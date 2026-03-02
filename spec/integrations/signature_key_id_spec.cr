require "../../src/views/view_helper"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe "signature keyId integration" do
  setup_spec

  module ::Ktistec::ViewHelper
    def self.render_actor_json_ecr(env, actor)
      render "./src/views/actors/actor.json.ecr"
    end
  end

  let_create(:actor, with_keys: true, local: true)

  let(env) { make_env("GET", "/actors/#{actor.username}") }

  let(public_key_id) do
    JSON.parse(::Ktistec::ViewHelper.render_actor_json_ecr(env, actor)).dig("publicKey", "id").as_s
  end

  let(signature_key_id) do
    $1 if Ktistec::Signature.sign(actor, "https://remote.test/inbox", "body")["Signature"] =~ /keyId="([^"]+)"/
  end

  it "keyId in HTTP signature matches publicKey.id in actor JSON" do
    expect(signature_key_id).to eq(public_key_id)
  end
end
