require "../spec_helper"

module WebFinger
  def self.query(account)
    WebFinger::Result.from_json(<<-JSON
      {
        "links":[
          {
            "rel":"self",
            "href":"https://test.test/foo_bar"
          }
        ]
      }
      JSON
    )
  end
end

class HTTP::Client
  def self.get(url : String, headers : HTTP::Headers)
    HTTP::Client::Response.new(
      200,
      headers: HTTP::Headers.new,
      body: <<-JSON
        {
          "@context":[
            "https://www.w3.org/ns/activitystreams"
          ],
          "type":"Person",
          "id":"https://test.test/foo_bar",
          "preferredUsername":"foo_bar"
        }
        JSON
    )
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
        it "looks up an actor" do
          headers = HTTP::Headers{"Accept" => "text/html"}
          get "/api/lookup?account=foobar@test.test", headers
          expect(response.status_code).to eq(200)
          expect(XML.parse_html(response.body).xpath_nodes("//div[@class='actor']/h1/a[contains(text(),'foo_bar')]")).not_to be_empty
        end

        it "looks up an actor" do
          headers = HTTP::Headers{"Accept" => "application/json"}
          get "/api/lookup?account=foobar@test.test", headers
          expect(response.status_code).to eq(200)
          expect(JSON.parse(response.body).as_h.dig("actor", "username")).to eq("foo_bar")
        end
      end
    end
  end
end
