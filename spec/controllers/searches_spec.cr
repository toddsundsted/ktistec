require "../../src/controllers/searches"
require "../../src/models/activity_pub/activity/follow"
require "../../src/models/activity_pub/activity/like"
require "../../src/models/relationship/content/outbox"
require "../../src/models/relationship/social/follow"

require "../spec_helper/factory"
require "../spec_helper/controller"
require "../spec_helper/network"

Spectator.describe SearchesController do
  setup_spec

  HTML_HEADERS = HTTP::Headers{"Accept" => "text/html"}
  JSON_HEADERS = HTTP::Headers{"Accept" => "application/json"}

  describe "GET /search" do
    it "returns 401 if not authorized" do
      get "/search", HTML_HEADERS
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      get "/search", JSON_HEADERS
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      let(actor) { register.actor }

      sign_in(as: actor.username)

      it "presents a search form" do
        get "/search", HTML_HEADERS
        expect(response.status_code).to eq(200)
        expect(XML.parse_html(response.body).xpath_nodes("//form[.//input[@name='query']]")).not_to be_empty
      end

      it "presents a search form" do
        get "/search", JSON_HEADERS
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).as_h.keys).to have("query")
      end

      let_build(:actor, named: :other, iri: "https://remote/actors/foo_bar")

      before_each { HTTP::Client.actors << other.assign(username: "foo_bar") }

      let_build(:object, iri: "https://remote/objects/foo_bar", attributed_to: other)

      before_each { HTTP::Client.objects << object.assign(content: "foo bar") }

      context "given a username" do
        let_create!(:actor, named: :alice, username: "alice")
        let_create!(:actor, named: :alicia, username: "alicia")
        let_create!(:actor, named: :bob, username: "bob")

        it "returns matching actors" do
          get "/search?query=al", HTML_HEADERS
          expect(response.status_code).to eq(200)
          body = XML.parse_html(response.body)
          usernames = body.xpath_nodes("//div[@class='ui basic segment']//a[1]").map(&.text.strip)
          expect(usernames).to contain_exactly("alice", "alicia")
        end

        it "returns matching actors" do
          get "/search?query=al", JSON_HEADERS
          expect(response.status_code).to eq(200)
          actors = JSON.parse(response.body).as_h["actors"].as_a
          usernames = actors.map { |a| a.as_h["username"].as_s }
          expect(usernames).to contain_exactly("alice", "alicia")
        end

        it "returns empty results when no matches found" do
          get "/search?query=xyz", HTML_HEADERS
          expect(response.status_code).to eq(200)
          body = XML.parse_html(response.body)
          expect(body.xpath_nodes("//div[contains(@class,'error message')]").first).to match(/No actors found/)
        end

        it "returns empty results when no matches found" do
          get "/search?query=xyz", JSON_HEADERS
          expect(response.status_code).to eq(200)
          json = JSON.parse(response.body).as_h
          expect(json["msg"]).to match(/No actors found/)
        end

        it "strips leading @ from username query" do
          get "/search?query=@al", HTML_HEADERS
          expect(response.status_code).to eq(200)
          body = XML.parse_html(response.body)
          usernames = body.xpath_nodes("//div[@class='ui basic segment']//a[1]").map(&.text.strip)
          expect(usernames).to contain_exactly("alice", "alicia")
        end

        it "strips leading @ from username query" do
          get "/search?query=@al", JSON_HEADERS
          expect(response.status_code).to eq(200)
          actors = JSON.parse(response.body).as_h["actors"].as_a
          usernames = actors.map { |a| a.as_h["username"].as_s }
          expect(usernames).to contain_exactly("alice", "alicia")
        end

        it "rejects queries longer than 100 characters" do
          long_query = "a" * 101
          get "/search?query=#{long_query}", HTML_HEADERS
          expect(response.status_code).to eq(200)
          body = XML.parse_html(response.body)
          expect(body.xpath_nodes("//div[contains(@class,'error message')]").first).to match(/too long/)
        end

        it "rejects queries longer than 100 characters" do
          long_query = "a" * 101
          get "/search?query=#{long_query}", JSON_HEADERS
          expect(response.status_code).to eq(200)
          json = JSON.parse(response.body).as_h
          expect(json["msg"]).to match(/too long/)
        end
      end

      context "given a handle to an actor" do
        it "retrieves and saves an actor" do
          expect{get "/search?query=foo_bar@remote", HTML_HEADERS}.to change{ActivityPub::Actor.count}.by(1)
          expect(response.status_code).to eq(200)
          expect(XML.parse_html(response.body).xpath_nodes("//div/a[contains(text(),'foo_bar')]")).not_to be_empty
        end

        it "retrieves and saves an actor" do
          expect{get "/search?query=foo_bar@remote", JSON_HEADERS}.to change{ActivityPub::Actor.count}.by(1)
          expect(response.status_code).to eq(200)
          expect(JSON.parse(response.body).as_h.dig("actor", "username")).to eq("foo_bar")
        end

        it "works with a leading @ if present" do
          expect{get "/search?query=@foo_bar@remote", HTML_HEADERS}.to change{ActivityPub::Actor.count}.by(1)
          expect(response.status_code).to eq(200)
          expect(XML.parse_html(response.body).xpath_nodes("//div/a[contains(text(),'foo_bar')]")).not_to be_empty
        end

        it "works with a leading @ if present" do
          expect{get "/search?query=@foo_bar@remote", JSON_HEADERS}.to change{ActivityPub::Actor.count}.by(1)
          expect(response.status_code).to eq(200)
          expect(JSON.parse(response.body).as_h.dig("actor", "username")).to eq("foo_bar")
        end

        it "ignores surrounding whitespace if present" do
          expect{get "/search?query=+foo_bar@remote+", HTML_HEADERS}.to change{ActivityPub::Actor.count}.by(1)
          expect(response.status_code).to eq(200)
          expect(XML.parse_html(response.body).xpath_nodes("//div/a[contains(text(),'foo_bar')]")).not_to be_empty
        end

        it "ignores surrounding whitespace if present" do
          expect{get "/search?query=+foo_bar@remote+", JSON_HEADERS}.to change{ActivityPub::Actor.count}.by(1)
          expect(response.status_code).to eq(200)
          expect(JSON.parse(response.body).as_h.dig("actor", "username")).to eq("foo_bar")
        end

        context "that already exists" do
          before_each { other.assign(username: "bar_foo").save }

          it "updates the actor" do
            expect{get "/search?query=foo_bar@remote", HTML_HEADERS}.not_to change{ActivityPub::Actor.count}
            expect(other.reload!.username).to eq("foo_bar")
          end

          it "updates the actor" do
            expect{get "/search?query=foo_bar@remote", JSON_HEADERS}.not_to change{ActivityPub::Actor.count}
            expect(other.reload!.username).to eq("foo_bar")
          end

          it "presents a follow button" do
            get "/search?query=foo_bar@remote", HTML_HEADERS
            expect(XML.parse_html(response.body).xpath_nodes("//form//button[./text()='Follow']")).not_to be_empty
          end

          context "with an existing follow" do
            let_create!(:follow, actor: actor, object: other)
            let_create!(:follow_relationship, actor: actor, object: other)

            it "presents an unfollow button" do
              get "/search?query=foo_bar@remote", HTML_HEADERS
              expect(XML.parse_html(response.body).xpath_nodes("//form//button[./text()='Unfollow']")).not_to be_empty
            end
          end

          context "with a public key" do
            before_each do
              other.assign(pem_public_key: "OLD PEM PUBLIC KEY").save
              HTTP::Client.actors << other.assign(pem_public_key: "NEW PEM PUBLIC KEY")
            end

            it "updates the public key" do
              expect{get "/search?query=foo_bar@remote", HTML_HEADERS}.to change{other.reload!.pem_public_key}.to("NEW PEM PUBLIC KEY")
            end
          end
        end

        context "that is local" do
          before_each { other.assign(iri: "https://test.test/actors/foo_bar").save }

          it "doesn't fetch the actor" do
            expect{get "/search?query=foo_bar@test.test", HTML_HEADERS}.not_to change{ActivityPub::Actor.count}
            expect(HTTP::Client.requests).not_to have("GET #{other.iri}")
          end
        end

        context "that is down" do
          before_each { other.save.down! }

          it "marks the actor as up" do
            expect{get "/search?query=foo_bar@remote", HTML_HEADERS}.to change{other.reload!.up?}.to(true)
          end
        end
      end

      context "given a URL to an actor" do
        it "retrieves and saves an actor" do
          expect{get "/search?query=https://remote/actors/foo_bar", HTML_HEADERS}.to change{ActivityPub::Actor.count}.by(1)
          expect(response.status_code).to eq(200)
          expect(XML.parse_html(response.body).xpath_nodes("//div/a[contains(text(),'foo_bar')]")).not_to be_empty
        end

        it "retrieves and saves an actor" do
          expect{get "/search?query=https://remote/actors/foo_bar", JSON_HEADERS}.to change{ActivityPub::Actor.count}.by(1)
          expect(response.status_code).to eq(200)
          expect(JSON.parse(response.body).as_h.dig("actor", "username")).to eq("foo_bar")
        end

        context "that already exists" do
          before_each { other.assign(username: "bar_foo").save }

          it "updates the actor" do
            expect{get "/search?query=https://remote/actors/foo_bar", HTML_HEADERS}.not_to change{ActivityPub::Actor.count}
            expect(other.reload!.username).to eq("foo_bar")
          end

          it "updates the actor" do
            expect{get "/search?query=https://remote/actors/foo_bar", JSON_HEADERS}.not_to change{ActivityPub::Actor.count}
            expect(other.reload!.username).to eq("foo_bar")
          end

          it "presents a follow button" do
            get "/search?query=https://remote/actors/foo_bar", HTML_HEADERS
            expect(XML.parse_html(response.body).xpath_nodes("//form//button[./text()='Follow']")).not_to be_empty
          end

          context "with an existing follow" do
            let_create!(:follow, actor: actor, object: other)
            let_create!(:follow_relationship, actor: actor, object: other)

            it "presents an unfollow button" do
              get "/search?query=https://remote/actors/foo_bar", HTML_HEADERS
              expect(XML.parse_html(response.body).xpath_nodes("//form//button[./text()='Unfollow']")).not_to be_empty
            end
          end

          context "with a public key" do
            before_each do
              other.assign(pem_public_key: "OLD PEM PUBLIC KEY").save
              HTTP::Client.actors << other.assign(pem_public_key: "NEW PEM PUBLIC KEY")
            end

            it "updates the public key" do
              expect{get "/search?query=https://remote/actors/foo_bar", HTML_HEADERS}.to change{other.reload!.pem_public_key}.to("NEW PEM PUBLIC KEY")
            end
          end
        end

        context "that is local" do
          before_each { other.assign(iri: "https://test.test/actors/foo_bar").save }

          it "doesn't fetch the actor" do
            expect{get "/search?query=https://test.test/actors/foo_bar", HTML_HEADERS}.not_to change{ActivityPub::Actor.count}
            expect(HTTP::Client.requests).not_to have("GET #{other.iri}")
          end
        end

        context "that is down" do
          before_each { other.save.down! }

          it "marks the actor as up" do
            expect{get "/search?query=https://remote/actors/foo_bar", HTML_HEADERS}.to change{other.reload!.up?}.to(true)
          end
        end
      end

      context "given a URL to an object" do
        it "retrieves and saves an object" do
          expect{get "/search?query=https://remote/objects/foo_bar", HTML_HEADERS}.to change{ActivityPub::Object.count}.by(1)
          expect(response.status_code).to eq(200)
          expect(XML.parse_html(response.body).xpath_nodes("//div[contains(text(),'foo bar')]")).not_to be_empty
        end

        it "retrieves and saves an object" do
          expect{get "/search?query=https://remote/objects/foo_bar", JSON_HEADERS}.to change{ActivityPub::Object.count}.by(1)
          expect(response.status_code).to eq(200)
          expect(JSON.parse(response.body).as_h.dig("object", "content")).to eq("foo bar")
        end

        context "of an existing object" do
          before_each { object.assign(content: "bar foo").save }

          it "updates the object" do
            expect{get "/search?query=https://remote/objects/foo_bar", HTML_HEADERS}.not_to change{ActivityPub::Object.count}
            expect(object.reload!.content).to eq("foo bar")
          end

          it "updates the object" do
            expect{get "/search?query=https://remote/objects/foo_bar", JSON_HEADERS}.not_to change{ActivityPub::Object.count}
            expect(object.reload!.content).to eq("foo bar")
          end

          it "presents a like button" do
            get "/search?query=https://remote/objects/foo_bar", HTML_HEADERS
            expect(XML.parse_html(response.body).xpath_nodes("//form//input[@value='Like']")).not_to be_empty
          end

          context "with an existing like" do
            let_build(:like, actor: actor, object: object)

            before_each do
              put_in_outbox(actor, like)
            end

            it "presents an undo button" do
              get "/search?query=https://remote/objects/foo_bar", HTML_HEADERS
              expect(XML.parse_html(response.body).xpath_nodes("//form//input[@value='Undo']")).not_to be_empty
            end
          end
        end

        context "of a local object" do
          before_each { object.assign(iri: "https://test.test/objects/foo_bar").save }

          it "doesn't fetch the object" do
            expect{get "/search?query=https://test.test/objects/foo_bar", HTML_HEADERS}.not_to change{ActivityPub::Object.count}
            expect(HTTP::Client.requests).not_to have("GET #{object.iri}")
          end
        end
      end

      context "given a non-existent host" do
        it "returns 400" do
          get "/search?query=foo_bar@no-such-host", HTML_HEADERS
          expect(response.status_code).to eq(400)
          expect(XML.parse_html(response.body).xpath_nodes("//div[contains(@class,'error message')]").first).to match(/No such host/)
        end

        it "returns 400" do
          get "/search?query=foo_bar@no-such-host", JSON_HEADERS
          expect(response.status_code).to eq(400)
          expect(JSON.parse(response.body).as_h["msg"]).to match(/No such host/)
        end
      end

      context "given bad JSON" do
        it "returns 400" do
          get "/search?query=bad-json@remote", HTML_HEADERS
          expect(response.status_code).to eq(400)
          expect(XML.parse_html(response.body).xpath_nodes("//div[contains(@class,'error message')]").first).to match(/Unexpected char/)
        end

        it "returns 400" do
          get "/search?query=bad-json@remote", JSON_HEADERS
          expect(response.status_code).to eq(400)
          expect(JSON.parse(response.body).as_h["msg"]).to match(/Unexpected char/)
        end
      end
    end
  end
end
