require "../../src/controllers/design_system"

require "../spec_helper/controller"
require "../spec_helper/factory"

Spectator.describe DesignSystemController do
  setup_spec

  let(actor) { register.actor }

  describe "GET /.design-system" do
    it "returns 401 if not authorized" do
      get "/.design-system"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "succeeds" do
        get "/.design-system"
        expect(response.status_code).to eq(200)
      end
    end
  end
end
