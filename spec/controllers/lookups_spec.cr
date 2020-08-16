require "../spec_helper"

module WebFinger
  def self.query(account)
    account =~ /^acct:([^@]+)@([^@]+)$/
    _, name, host = $~.to_a
    case account
    when /no-such-host/
      raise WebFinger::NotFoundError.new("No such host")
    else
      WebFinger::Result.from_json(<<-JSON
        {
          "links":[
            {
              "rel":"self",
              "href":"https://#{host}/actors/#{name}"
            }
          ]
        }
        JSON
      )
    end
  end
end

Spectator.describe LookupsController do
  before_each { HTTP::Client.reset }
  before_each { Balloon.database.exec "BEGIN TRANSACTION" }
  after_each { Balloon.database.exec "ROLLBACK" }

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
        expect(XML.parse_html(response.body).xpath_nodes("//form[./input[@name='account']]")).not_to be_empty
      end

      it "presents a search form" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/search", headers
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).as_h.keys).to have("account")
      end

      context "given a handle" do
        let(actor) { ActivityPub::Actor.new(iri: "https://test.test/actors/foo_bar") }

        before_each { HTTP::Client.actors << actor.dup.assign(username: "foo_bar") }

        it "retrieves and saves an actor" do
          headers = HTTP::Headers{"Accept" => "text/html"}
          expect{get "/search?account=foo_bar@test.test", headers}.to change{ActivityPub::Actor.count}.by(1)
          expect(response.status_code).to eq(200)
          expect(XML.parse_html(response.body).xpath_nodes("//div[contains(@class,'actor')]/p/a[contains(text(),'foo_bar')]")).not_to be_empty
        end

        it "retrieves and saves an actor" do
          headers = HTTP::Headers{"Accept" => "application/json"}
          expect{get "/search?account=foo_bar@test.test", headers}.to change{ActivityPub::Actor.count}.by(1)
          expect(response.status_code).to eq(200)
          expect(JSON.parse(response.body).as_h.dig("actor", "username")).to eq("foo_bar")
        end

        context "to an existing actor" do
          before_each { actor.save }

          it "updates the actor" do
            headers = HTTP::Headers{"Accept" => "text/html"}
            expect{get "/search?account=foo_bar@test.test", headers}.not_to change{ActivityPub::Actor.count}
            expect(ActivityPub::Actor.find("https://test.test/actors/foo_bar").username).to eq("foo_bar")
          end

          it "updates the actor" do
            headers = HTTP::Headers{"Accept" => "application/json"}
            expect{get "/search?account=foo_bar@test.test", headers}.not_to change{ActivityPub::Actor.count}
            expect(ActivityPub::Actor.find("https://test.test/actors/foo_bar").username).to eq("foo_bar")
          end

          it "presents a follow button" do
            headers = HTTP::Headers{"Accept" => "text/html"}
            get "/search?account=foo_bar@test.test", headers
            expect(XML.parse_html(response.body).xpath_nodes("//div[contains(@class,'actor')]/form/input[@value='Follow']")).not_to be_empty
          end

          context "with an existing relationship" do
            let!(relationship) { Relationship::Social::Follow.new(from_iri: Global.account.try(&.iri), to_iri: actor.iri).save }

            it "presents an unfollow button" do
              headers = HTTP::Headers{"Accept" => "text/html"}
              get "/search?account=foo_bar@test.test", headers
              expect(XML.parse_html(response.body).xpath_nodes("//div[contains(@class,'actor')]/form/input[@value='Unfollow']")).not_to be_empty
            end
          end
        end
      end

      context "given a URL" do
        let(actor) { ActivityPub::Actor.new(iri: "https://test.test/actors/foo_bar") }

        before_each { HTTP::Client.actors << actor.dup.assign(username: "foo_bar") }

        it "retrieves and stores an actor" do
          headers = HTTP::Headers{"Accept" => "text/html"}
          expect{get "/search?account=https://test.test/actors/foo_bar", headers}.to change{ActivityPub::Actor.count}.by(1)
          expect(response.status_code).to eq(200)
          expect(XML.parse_html(response.body).xpath_nodes("//div[contains(@class,'actor')]/p/a[contains(text(),'foo_bar')]")).not_to be_empty
        end

        it "retrieves and stores an actor" do
          headers = HTTP::Headers{"Accept" => "application/json"}
          expect{get "/search?account=https://test.test/actors/foo_bar", headers}.to change{ActivityPub::Actor.count}.by(1)
          expect(response.status_code).to eq(200)
          expect(JSON.parse(response.body).as_h.dig("actor", "username")).to eq("foo_bar")
        end

        context "to an existing actor" do
          before_each { actor.save }

          it "updates the actor" do
            headers = HTTP::Headers{"Accept" => "text/html"}
            expect{get "/search?account=https://test.test/actors/foo_bar", headers}.not_to change{ActivityPub::Actor.count}
            expect(ActivityPub::Actor.find("https://test.test/actors/foo_bar").username).to eq("foo_bar")
          end

          it "updates the actor" do
            headers = HTTP::Headers{"Accept" => "application/json"}
            expect{get "/search?account=https://test.test/actors/foo_bar", headers}.not_to change{ActivityPub::Actor.count}
            expect(ActivityPub::Actor.find("https://test.test/actors/foo_bar").username).to eq("foo_bar")
          end

          it "presents a follow button" do
            headers = HTTP::Headers{"Accept" => "text/html"}
            get "/search?account=https://test.test/actors/foo_bar", headers
            expect(XML.parse_html(response.body).xpath_nodes("//div[contains(@class,'actor')]/form/input[@value='Follow']")).not_to be_empty
          end

          context "with an existing relationship" do
            let!(relationship) { Relationship::Social::Follow.new(from_iri: Global.account.try(&.iri), to_iri: actor.iri).save }

            it "presents an unfollow button" do
              headers = HTTP::Headers{"Accept" => "text/html"}
              get "/search?account=https://test.test/actors/foo_bar", headers
              expect(XML.parse_html(response.body).xpath_nodes("//div[contains(@class,'actor')]/form/input[@value='Unfollow']")).not_to be_empty
            end
          end
        end
      end

      context "given a non-existent host" do
        it "returns 400" do
          headers = HTTP::Headers{"Accept" => "text/html"}
          get "/search?account=foo_bar@no-such-host", headers
          expect(response.status_code).to eq(400)
          expect(XML.parse_html(response.body).xpath_nodes("//p[@class='error message']").first.text).to match(/No such host/)
        end

        it "returns 400" do
          headers = HTTP::Headers{"Accept" => "application/json"}
          get "/search?account=foo_bar@no-such-host", headers
          expect(response.status_code).to eq(400)
          expect(JSON.parse(response.body).as_h["msg"]).to match(/No such host/)
        end
      end

      context "given bad JSON" do
        it "returns 400" do
          headers = HTTP::Headers{"Accept" => "text/html"}
          get "/search?account=bad-json@test.test", headers
          expect(response.status_code).to eq(400)
          expect(XML.parse_html(response.body).xpath_nodes("//p[@class='error message']").first.text).to match(/Unexpected char/)
        end

        it "returns 400" do
          headers = HTTP::Headers{"Accept" => "application/json"}
          get "/search?account=bad-json@test.test", headers
          expect(response.status_code).to eq(400)
          expect(JSON.parse(response.body).as_h["msg"]).to match(/Unexpected char/)
        end
      end
    end
  end
end
