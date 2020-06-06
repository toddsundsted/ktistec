require "../spec_helper"

Spectator.describe HomeController do
  before_each { Balloon.database.exec "BEGIN TRANSACTION" }
  after_each { Balloon.database.exec "ROLLBACK" }

  let(username) { random_string }
  let(password) { random_string }

  context "first time" do
    describe "GET /" do
      it "renders a form" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/", headers
        expect(response.status_code).to eq(200)
        expect(XML.parse_html(response.body).xpath_nodes("//form[./input[@name='username']][./input[@name='password']]")).not_to be_empty
      end

      it "returns a template" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/", headers
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).as_h.keys).to have("username", "password")
      end
    end

    describe "POST /" do
      it "redirects if params are missing" do
        headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
        post "/", headers
        expect(response.status_code).to eq(302)
        expect(response.headers.to_a).to have({"Location", ["/"]})
      end

      it "redirects if params are missing" do
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        post "/", headers
        expect(response.status_code).to eq(302)
        expect(response.headers.to_a).to have({"Location", ["/"]})
      end

      it "rerenders if params are invalid" do
        headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
        body = "username=&password=a1!"
        post "/", headers, body
        expect(response.status_code).to eq(200)
        expect(XML.parse_html(response.body).xpath_nodes("//div[./form]/p").first.text).to match(/username is too short, password is too short/)
      end

      it "rerenders if params are invalid" do
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        body = {username: "", password: "a1!"}.to_json
        post "/", headers, body
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body)["msg"]).to match(/username is too short, password is too short/)
      end

      it "creates account and redirects" do
        headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
        body = "username=#{username}&password=#{password}"
        expect{post "/", headers, body}.to change{Account.count}.by(1)
        expect(response.status_code).to eq(302)
        expect(response.headers["Set-Cookie"]).to be_truthy
      end

      it "also creates actor" do
        headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
        body = "username=#{username}&password=#{password}"
        expect{post "/", headers, body}.to change{ActivityPub::Actor.count}.by(1)
      end

      it "creates account" do
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        body = {username: username, password: password}.to_json
        expect{post "/", headers, body}.to change{Account.count}.by(1)
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body)["jwt"]).to be_truthy
      end

      it "also creates actor" do
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        body = {username: username, password: password}.to_json
        expect{post "/", headers, body}.to change{ActivityPub::Actor.count}.by(1)
      end
    end
  end

  context "home page" do
    let!(account) do
      Account.new(username, password).tap do |account|
        account.actor = ActivityPub::Actor.new(
          iri: "https://test.test/#{username}",
          username: username
        ).save
      end.save
    end

    describe "GET /" do
      it "renders a list of local actors" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/", headers
        expect(response.status_code).to eq(200)
        expect(XML.parse_html(response.body).xpath_nodes("//p/a[contains(@href,'#{username}')]/@href").first.text).to match(/actors\/#{username}/)
      end

      it "renders a list of local actors" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/", headers
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body)["items"].as_a.first).to match(/actors\/#{username}/)
      end
    end

    describe "POST /" do
      it "returns 404" do
        post "/"
        expect(response.status_code).to eq(404)
      end

      it "returns 404" do
        post "/"
        expect(response.status_code).to eq(404)
      end
    end
  end
end
