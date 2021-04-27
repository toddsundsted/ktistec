require "../../src/controllers/searches"
require "../../src/models/activity_pub/activity/follow"
require "../../src/models/activity_pub/activity/like"
require "../../src/models/relationship/content/outbox"
require "../../src/models/relationship/social/follow"

require "../spec_helper/controller"
require "../spec_helper/network"

Spectator.describe SearchesController do
  setup_spec

  describe "GET /search" do
    it "returns 401 if not authorized" do
      headers = HTTP::Headers{"Accept" => "text/html"}
      get "/search", headers
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      headers = HTTP::Headers{"Accept" => "application/json"}
      get "/search", headers
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in

      it "presents a search form" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/search", headers
        expect(response.status_code).to eq(200)
        expect(XML.parse_html(response.body).xpath_nodes("//form[.//input[@name='query']]")).not_to be_empty
      end

      it "presents a search form" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/search", headers
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).as_h.keys).to have("query")
      end

      let(actor) { ActivityPub::Actor.new(iri: "https://remote/actors/foo_bar") }

      before_each { HTTP::Client.actors << actor.assign(username: "foo_bar") }

      let(object) { ActivityPub::Object.new(iri: "https://remote/objects/foo_bar", attributed_to: actor) }

      before_each { HTTP::Client.objects << object.assign(content: "foo bar") }

      context "given a handle" do
        it "retrieves and saves an actor" do
          headers = HTTP::Headers{"Accept" => "text/html"}
          expect{get "/search?query=foo_bar@remote", headers}.to change{ActivityPub::Actor.count}.by(1)
          expect(response.status_code).to eq(200)
          expect(XML.parse_html(response.body).xpath_nodes("//div[contains(text(),'foo_bar')]")).not_to be_empty
        end

        it "retrieves and saves an actor" do
          headers = HTTP::Headers{"Accept" => "application/json"}
          expect{get "/search?query=foo_bar@remote", headers}.to change{ActivityPub::Actor.count}.by(1)
          expect(response.status_code).to eq(200)
          expect(JSON.parse(response.body).as_h.dig("actor", "username")).to eq("foo_bar")
        end

        context "of an existing actor" do
          before_each { actor.assign(username: "bar_foo").save }

          it "updates the actor" do
            headers = HTTP::Headers{"Accept" => "text/html"}
            expect{get "/search?query=foo_bar@remote", headers}.not_to change{ActivityPub::Actor.count}
            expect(ActivityPub::Actor.find("https://remote/actors/foo_bar").username).to eq("foo_bar")
          end

          it "updates the actor" do
            headers = HTTP::Headers{"Accept" => "application/json"}
            expect{get "/search?query=foo_bar@remote", headers}.not_to change{ActivityPub::Actor.count}
            expect(ActivityPub::Actor.find("https://remote/actors/foo_bar").username).to eq("foo_bar")
          end

          it "presents a follow button" do
            headers = HTTP::Headers{"Accept" => "text/html"}
            get "/search?query=foo_bar@remote", headers
            expect(XML.parse_html(response.body).xpath_nodes("//form//button[./text()='Follow']")).not_to be_empty
          end

          context "with an existing follow" do
            before_each do
              ActivityPub::Activity::Follow.new(iri: "https://remote/#{random_string}", actor: Global.account.try(&.actor), object: actor).save
              Relationship::Social::Follow.new(actor: Global.account.try(&.actor), object: actor).save
            end

            it "presents an unfollow button" do
              headers = HTTP::Headers{"Accept" => "text/html"}
              get "/search?query=foo_bar@remote", headers
              expect(XML.parse_html(response.body).xpath_nodes("//form//button[./text()='Unfollow']")).not_to be_empty
            end
          end

          context "with a public key" do
            before_each do
              HTTP::Client.actors << actor.assign(pem_public_key: "PEM PUBLIC KEY").save
            end

            it "doesn't nuke the public key" do
              headers = HTTP::Headers{"Accept" => "text/html"}
              expect{get "/search?query=foo_bar@remote", headers}.not_to change{ActivityPub::Actor.find(actor.iri).pem_public_key}
            end
          end
        end

        context "of a local actor" do
          before_each { actor.assign(iri: "https://test.test/actors/foo_bar").save }

          it "doesn't fetch the actor" do
            headers = HTTP::Headers{"Accept" => "text/html"}
            expect{get "/search?query=foo_bar@test.test", headers}.not_to change{ActivityPub::Actor.count}
            expect(HTTP::Client.requests).not_to have("GET #{actor.iri}")
          end
        end
      end

      context "given a URL to an actor" do
        it "retrieves and saves an actor" do
          headers = HTTP::Headers{"Accept" => "text/html"}
          expect{get "/search?query=https://remote/actors/foo_bar", headers}.to change{ActivityPub::Actor.count}.by(1)
          expect(response.status_code).to eq(200)
          expect(XML.parse_html(response.body).xpath_nodes("//div[contains(text(),'foo_bar')]")).not_to be_empty
        end

        it "retrieves and saves an actor" do
          headers = HTTP::Headers{"Accept" => "application/json"}
          expect{get "/search?query=https://remote/actors/foo_bar", headers}.to change{ActivityPub::Actor.count}.by(1)
          expect(response.status_code).to eq(200)
          expect(JSON.parse(response.body).as_h.dig("actor", "username")).to eq("foo_bar")
        end

        context "of an existing actor" do
          before_each { actor.assign(username: "bar_foo").save }

          it "updates the actor" do
            headers = HTTP::Headers{"Accept" => "text/html"}
            expect{get "/search?query=https://remote/actors/foo_bar", headers}.not_to change{ActivityPub::Actor.count}
            expect(ActivityPub::Actor.find("https://remote/actors/foo_bar").username).to eq("foo_bar")
          end

          it "updates the actor" do
            headers = HTTP::Headers{"Accept" => "application/json"}
            expect{get "/search?query=https://remote/actors/foo_bar", headers}.not_to change{ActivityPub::Actor.count}
            expect(ActivityPub::Actor.find("https://remote/actors/foo_bar").username).to eq("foo_bar")
          end

          it "presents a follow button" do
            headers = HTTP::Headers{"Accept" => "text/html"}
            get "/search?query=https://remote/actors/foo_bar", headers
            expect(XML.parse_html(response.body).xpath_nodes("//form//button[./text()='Follow']")).not_to be_empty
          end

          context "with an existing follow" do
            before_each do
              ActivityPub::Activity::Follow.new(iri: "https://remote/#{random_string}", actor: Global.account.try(&.actor), object: actor).save
              Relationship::Social::Follow.new(actor: Global.account.try(&.actor), object: actor).save
            end

            it "presents an unfollow button" do
              headers = HTTP::Headers{"Accept" => "text/html"}
              get "/search?query=https://remote/actors/foo_bar", headers
              expect(XML.parse_html(response.body).xpath_nodes("//form//button[./text()='Unfollow']")).not_to be_empty
            end
          end

          context "with a public key" do
            before_each do
              HTTP::Client.actors << actor.assign(pem_public_key: "PEM PUBLIC KEY").save
            end

            it "doesn't nuke the public key" do
              headers = HTTP::Headers{"Accept" => "text/html"}
              expect{get "/search?query=https://remote/actors/foo_bar", headers}.not_to change{ActivityPub::Actor.find(actor.iri).pem_public_key}
            end
          end
        end

        context "of a local actor" do
          before_each { actor.assign(iri: "https://test.test/actors/foo_bar").save }

          it "doesn't fetch the actor" do
            headers = HTTP::Headers{"Accept" => "text/html"}
            expect{get "/search?query=https://test.test/actors/foo_bar", headers}.not_to change{ActivityPub::Actor.count}
            expect(HTTP::Client.requests).not_to have("GET #{actor.iri}")
          end
        end
      end

      context "given a URL to an object" do
        it "retrieves and saves an object" do
          headers = HTTP::Headers{"Accept" => "text/html"}
          expect{get "/search?query=https://remote/objects/foo_bar", headers}.to change{ActivityPub::Object.count}.by(1)
          expect(response.status_code).to eq(200)
          expect(XML.parse_html(response.body).xpath_nodes("//div[contains(text(),'foo bar')]")).not_to be_empty
        end

        it "retrieves and saves an object" do
          headers = HTTP::Headers{"Accept" => "application/json"}
          expect{get "/search?query=https://remote/objects/foo_bar", headers}.to change{ActivityPub::Object.count}.by(1)
          expect(response.status_code).to eq(200)
          expect(JSON.parse(response.body).as_h.dig("object", "content")).to eq("foo bar")
        end

        context "of an existing object" do
          before_each { object.assign(content: "bar foo").save }

          it "updates the object" do
            headers = HTTP::Headers{"Accept" => "text/html"}
            expect{get "/search?query=https://remote/objects/foo_bar", headers}.not_to change{ActivityPub::Object.count}
            expect(ActivityPub::Object.find("https://remote/objects/foo_bar").content).to eq("foo bar")
          end

          it "updates the object" do
            headers = HTTP::Headers{"Accept" => "application/json"}
            expect{get "/search?query=https://remote/objects/foo_bar", headers}.not_to change{ActivityPub::Object.count}
            expect(ActivityPub::Object.find("https://remote/objects/foo_bar").content).to eq("foo bar")
          end

          it "presents a like button" do
            headers = HTTP::Headers{"Accept" => "text/html"}
            get "/search?query=https://remote/objects/foo_bar", headers
            expect(XML.parse_html(response.body).xpath_nodes("//form//input[@value='Like']")).not_to be_empty
          end

          context "with an existing like" do
            before_each do
              like = ActivityPub::Activity::Like.new(iri: "https://remote/#{random_string}", actor: Global.account.try(&.actor), object: object).save
              Relationship::Content::Outbox.new(owner: Global.account.try(&.actor), activity: like).save
            end

            it "presents an undo button" do
              headers = HTTP::Headers{"Accept" => "text/html"}
              get "/search?query=https://remote/objects/foo_bar", headers
              expect(XML.parse_html(response.body).xpath_nodes("//form//input[@value='Undo']")).not_to be_empty
            end
          end
        end

        context "of a local object" do
          before_each { object.assign(iri: "https://test.test/objects/foo_bar").save }

          it "doesn't fetch the object" do
            headers = HTTP::Headers{"Accept" => "text/html"}
            expect{get "/search?query=https://test.test/objects/foo_bar", headers}.not_to change{ActivityPub::Object.count}
            expect(HTTP::Client.requests).not_to have("GET #{object.iri}")
          end
        end
      end

      context "given a non-existent host" do
        it "returns 400" do
          headers = HTTP::Headers{"Accept" => "text/html"}
          get "/search?query=foo_bar@no-such-host", headers
          expect(response.status_code).to eq(400)
          expect(XML.parse_html(response.body).xpath_nodes("//div[contains(@class,'error message')]").first.text).to match(/No such host/)
        end

        it "returns 400" do
          headers = HTTP::Headers{"Accept" => "application/json"}
          get "/search?query=foo_bar@no-such-host", headers
          expect(response.status_code).to eq(400)
          expect(JSON.parse(response.body).as_h["msg"]).to match(/No such host/)
        end
      end

      context "given bad JSON" do
        it "returns 400" do
          headers = HTTP::Headers{"Accept" => "text/html"}
          get "/search?query=bad-json@remote", headers
          expect(response.status_code).to eq(400)
          expect(XML.parse_html(response.body).xpath_nodes("//div[contains(@class,'error message')]").first.text).to match(/Unexpected char/)
        end

        it "returns 400" do
          headers = HTTP::Headers{"Accept" => "application/json"}
          get "/search?query=bad-json@remote", headers
          expect(response.status_code).to eq(400)
          expect(JSON.parse(response.body).as_h["msg"]).to match(/Unexpected char/)
        end
      end
    end
  end
end
