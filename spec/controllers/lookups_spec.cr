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
              "href":"https://#{host}/#{name}"
            }
          ]
        }
        JSON
      )
    end
  end
end

class HTTP::Client
  def self.get(url : String, headers : HTTP::Headers)
    url = URI.parse(url)
    case url.path
    when /bad-json/
      HTTP::Client::Response.new(
        200,
        headers: HTTP::Headers.new,
        body: "bad json"
      )
    else
      HTTP::Client::Response.new(
        200,
        headers: HTTP::Headers.new,
        body: <<-JSON
          {
            "@context":[
              "https://www.w3.org/ns/activitystreams"
            ],
            "type":"Person",
            "id":"https://#{url.host}/#{url.path[1..-1]}",
            "preferredUsername":"#{url.path[1..-1]}"
          }
          JSON
      )
    end
  end
end

Spectator.describe LookupsController do
  before_each { Balloon.database.exec "BEGIN TRANSACTION" }
  after_each { Balloon.database.exec "ROLLBACK" }

  describe "GET /api/lookup" do
    it "returns 401 if not authorized" do
      headers = HTTP::Headers{"Accept" => "text/html"}
      get "/api/lookup", headers
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      headers = HTTP::Headers{"Accept" => "application/json"}
      get "/api/lookup", headers
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in

      it "presents a lookup form" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/api/lookup", headers
        expect(response.status_code).to eq(200)
        expect(XML.parse_html(response.body).xpath_nodes("//form[./input[@name='account']]")).not_to be_empty
      end

      it "presents a lookup form" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/api/lookup", headers
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).as_h.keys).to have("account")
      end

      context "given a handle" do
        it "retrieves and saves an actor" do
          headers = HTTP::Headers{"Accept" => "text/html"}
          expect{get "/api/lookup?account=foo_bar@test.test", headers}.to change{ActivityPub::Actor.count}.by(1)
          expect(response.status_code).to eq(200)
          expect(XML.parse_html(response.body).xpath_nodes("//div[@class='actor']/h1/a[contains(text(),'foo_bar')]")).not_to be_empty
        end

        it "retrieves and saves an actor" do
          headers = HTTP::Headers{"Accept" => "application/json"}
          expect{get "/api/lookup?account=foo_bar@test.test", headers}.to change{ActivityPub::Actor.count}.by(1)
          expect(response.status_code).to eq(200)
          expect(JSON.parse(response.body).as_h.dig("actor", "username")).to eq("foo_bar")
        end

        context "to an existing actor" do
          let!(actor) { ActivityPub::Actor.new(aid: "https://test.test/foo_bar").save }

          it "updates the actor" do
            headers = HTTP::Headers{"Accept" => "text/html"}
            expect{get "/api/lookup?account=foo_bar@test.test", headers}.not_to change{ActivityPub::Actor.count}
            expect(ActivityPub::Actor.find(aid: "https://test.test/foo_bar").username).to eq("foo_bar")
          end

          it "updates the actor" do
            headers = HTTP::Headers{"Accept" => "application/json"}
            expect{get "/api/lookup?account=foo_bar@test.test", headers}.not_to change{ActivityPub::Actor.count}
            expect(ActivityPub::Actor.find(aid: "https://test.test/foo_bar").username).to eq("foo_bar")
          end
        end
      end

      context "given a URL" do
        it "retrieves and stores an actor" do
          headers = HTTP::Headers{"Accept" => "text/html"}
          expect{get "/api/lookup?account=https://test.test/foo_bar", headers}.to change{ActivityPub::Actor.count}.by(1)
          expect(response.status_code).to eq(200)
          expect(XML.parse_html(response.body).xpath_nodes("//div[@class='actor']/h1/a[contains(text(),'foo_bar')]")).not_to be_empty
        end

        it "retrieves and stores an actor" do
          headers = HTTP::Headers{"Accept" => "application/json"}
          expect{get "/api/lookup?account=https://test.test/foo_bar", headers}.to change{ActivityPub::Actor.count}.by(1)
          expect(response.status_code).to eq(200)
          expect(JSON.parse(response.body).as_h.dig("actor", "username")).to eq("foo_bar")
        end

        context "to an existing actor" do
          let!(actor) { ActivityPub::Actor.new(aid: "https://test.test/foo_bar").save }

          it "updates the actor" do
            headers = HTTP::Headers{"Accept" => "text/html"}
            expect{get "/api/lookup?account=https://test.test/foo_bar", headers}.not_to change{ActivityPub::Actor.count}
            expect(ActivityPub::Actor.find(aid: "https://test.test/foo_bar").username).to eq("foo_bar")
          end

          it "updates the actor" do
            headers = HTTP::Headers{"Accept" => "application/json"}
            expect{get "/api/lookup?account=https://test.test/foo_bar", headers}.not_to change{ActivityPub::Actor.count}
            expect(ActivityPub::Actor.find(aid: "https://test.test/foo_bar").username).to eq("foo_bar")
          end
        end
      end

      context "given a non-existent host" do
        it "returns 400" do
          headers = HTTP::Headers{"Accept" => "text/html"}
          get "/api/lookup?account=foo_bar@no-such-host", headers
          expect(response.status_code).to eq(400)
          expect(XML.parse_html(response.body).xpath_nodes("//p[@class='error message']").first.text).to match(/No such host/)
        end

        it "returns 400" do
          headers = HTTP::Headers{"Accept" => "application/json"}
          get "/api/lookup?account=foo_bar@no-such-host", headers
          expect(response.status_code).to eq(400)
          expect(JSON.parse(response.body).as_h["msg"]).to match(/No such host/)
        end
      end

      context "given bad JSON" do
        it "returns 400" do
          headers = HTTP::Headers{"Accept" => "text/html"}
          get "/api/lookup?account=bad-json@test.test", headers
          expect(response.status_code).to eq(400)
          expect(XML.parse_html(response.body).xpath_nodes("//p[@class='error message']").first.text).to match(/Unexpected char/)
        end

        it "returns 400" do
          headers = HTTP::Headers{"Accept" => "application/json"}
          get "/api/lookup?account=bad-json@test.test", headers
          expect(response.status_code).to eq(400)
          expect(JSON.parse(response.body).as_h["msg"]).to match(/Unexpected char/)
        end
      end
    end
  end
end
