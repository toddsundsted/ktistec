require "../../src/controllers/searches"

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

      context "given a handle" do
        let(actor) { ActivityPub::Actor.new(iri: "https://remote/actors/foo_bar") }

        before_each { HTTP::Client.actors << actor.dup.assign(username: "foo_bar") }

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

        context "to an existing actor" do
          before_each { actor.save }

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
            expect(XML.parse_html(response.body).xpath_nodes("//form//input[@value='Follow']")).not_to be_empty
          end

          context "with an existing relationship" do
            before_each do
              ActivityPub::Activity::Follow.new(iri: "https://remote/#{random_string}", actor_iri: Global.account.try(&.iri), object_iri: actor.iri).save
              Relationship::Social::Follow.new(from_iri: Global.account.try(&.iri), to_iri: actor.iri).save
            end

            it "presents an unfollow button" do
              headers = HTTP::Headers{"Accept" => "text/html"}
              get "/search?query=foo_bar@remote", headers
              expect(XML.parse_html(response.body).xpath_nodes("//form//input[@value='Unfollow']")).not_to be_empty
            end
          end
        end
      end

      context "given a URL" do
        let(actor) { ActivityPub::Actor.new(iri: "https://remote/actors/foo_bar") }

        before_each { HTTP::Client.actors << actor.dup.assign(username: "foo_bar") }

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

        context "to an existing actor" do
          before_each { actor.save }

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
            expect(XML.parse_html(response.body).xpath_nodes("//form//input[@value='Follow']")).not_to be_empty
          end

          context "with an existing relationship" do
            before_each do
              ActivityPub::Activity::Follow.new(iri: "https://remote/#{random_string}", actor_iri: Global.account.try(&.iri), object_iri: actor.iri).save
              Relationship::Social::Follow.new(from_iri: Global.account.try(&.iri), to_iri: actor.iri).save
            end

            it "presents an unfollow button" do
              headers = HTTP::Headers{"Accept" => "text/html"}
              get "/search?query=https://remote/actors/foo_bar", headers
              expect(XML.parse_html(response.body).xpath_nodes("//form//input[@value='Unfollow']")).not_to be_empty
            end
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
