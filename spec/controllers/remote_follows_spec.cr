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
              "rel":"http://ostatus.org/schema/1.0/subscribe",
              "template":"https://#{host}/actors/#{name}/authorize-follow?uri={uri}"
            }
          ]
        }
        JSON
      )
    end
  end
end

Spectator.describe RemoteFollowsController do
  setup_spec

  let(actor) { register.actor }

  describe "GET /actors/:username/remote-follow" do
    context "when accepting HTML" do
      let(headers) { HTTP::Headers{"Accept" => "text/html"} }

      it "succeeds" do
        get "/actors/#{actor.username}/remote-follow", headers
        expect(response.status_code).to eq(200)
      end

      it "renders a form" do
        get "/actors/#{actor.username}/remote-follow", headers
        expect(XML.parse_html(response.body).xpath_nodes("//form[.//input[@name='account']]")).not_to be_empty
      end
    end

    context "when accepting JSON" do
      let(headers) { HTTP::Headers{"Accept" => "application/json"} }

      it "succeeds" do
        get "/actors/#{actor.username}/remote-follow", headers
        expect(response.status_code).to eq(200)
      end

      it "returns a template" do
        get "/actors/#{actor.username}/remote-follow", headers
        expect(JSON.parse(response.body).dig?("account")).not_to be_nil
      end
    end
  end

  describe "POST /actors/:username/remote-follow" do
    context "when posting form data" do
      let(headers) { HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"} }

      it "renders an error if address is missing" do
        post "/actors/#{actor.username}/remote-follow", headers, ""
        expect(XML.parse_html(response.body).xpath_nodes("//form/div[contains(@class,'error message')]/p").first.text).
          to match(/The address must not be blank/)
      end

      it "renders an error if address is blank" do
        post "/actors/#{actor.username}/remote-follow", headers, "account="
        expect(XML.parse_html(response.body).xpath_nodes("//form/div[contains(@class,'error message')]/p").first.text).
          to match(/The address must not be blank/)
      end

      it "retains the address if address is invalid" do
        post "/actors/#{actor.username}/remote-follow", headers, "account=xyz"
        expect(XML.parse_html(response.body).xpath_nodes("//form//input[@name='account']/@value").first.text).
          to eq("xyz")
      end

      it "redirects if succesful" do
        post "/actors/#{actor.username}/remote-follow", headers, "account=foobar%40remote.com"
        expect(response.status_code).to eq(302)
      end

      it "returns the remote location if successful" do
        post "/actors/#{actor.username}/remote-follow", headers, "account=foobar%40remote.com"
        expect(response.headers["Location"]?).
          to eq("https://remote.com/actors/foobar/authorize-follow?uri=#{actor.iri}")
      end
    end

    context "when posting JSON data" do
      let(headers) { HTTP::Headers{"Content-Type" => "application/json"} }

      it "returns an error message if address is missing" do
        post "/actors/#{actor.username}/remote-follow", headers, "{}"
        expect(JSON.parse(response.body).dig?("msg")).
          to match(/The address must not be blank/)
      end

      it "returns an error message if address is blank" do
        post "/actors/#{actor.username}/remote-follow", headers, {account: ""}.to_json
        expect(JSON.parse(response.body).dig?("msg")).
          to match(/The address must not be blank/)
      end

      it "retains the address if address is invalid" do
        post "/actors/#{actor.username}/remote-follow", headers, {account: "xyz"}.to_json
        expect(JSON.parse(response.body).dig?("account")).
          to eq("xyz")
      end

      it "succeeds" do
        post "/actors/#{actor.username}/remote-follow", headers, {account: "foobar@remote.com"}.to_json
        expect(response.status_code).to eq(200)
      end

      it "returns the remote location if successful" do
        post "/actors/#{actor.username}/remote-follow", headers, {account: "foobar@remote.com"}.to_json
        expect(JSON.parse(response.body).dig?("location")).
          to eq("https://remote.com/actors/foobar/authorize-follow?uri=#{actor.iri}")
      end
    end
  end
end
