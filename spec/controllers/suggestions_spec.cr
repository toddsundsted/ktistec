require "../../src/controllers/suggestions"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe SuggestionsController do
  setup_spec

  describe "GET /tags" do
    it "returns 401 if not authorized" do
      get "/tags"
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in

      let_build(:object, published: Time.local)

      context "hashtag" do
        macro create_tag(name)
          let_create!(:hashtag, named: nil, subject: object, name: {{name}})
        end

        create_tag("foobar")
        create_tag("foobar")
        create_tag("foo")
        create_tag("quux")

        it "returns the best match" do
          get "/tags?hashtag=foo"
          expect(response.status_code).to eq(200)
          expect(response.body).to eq("foobar")
        end
      end

      context "mention" do
        macro create_tag(name)
          let_create!(:mention, named: nil, subject: object, name: {{name}})
        end

        create_tag("gandalf")
        create_tag("gandalf")
        create_tag("frodo")
        create_tag("galadriel")

        it "returns the best match" do
          get "/tags?mention=gan"
          expect(response.status_code).to eq(200)
          expect(response.body).to eq("gandalf")
        end
      end

      it "returns 400 if no prefix is specified" do
        get "/tags"
        expect(response.status_code).to eq(400)
      end
    end
  end
end
