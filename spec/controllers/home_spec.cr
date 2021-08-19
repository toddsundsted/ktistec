require "../../src/controllers/home"

require "../spec_helper/controller"

Spectator.describe HomeController do
  setup_spec

  let(username) { random_username }
  let(password) { random_password }

  context "on step 1 (set host and site names)" do
    before_each do
      Ktistec.settings.clear_host
      Ktistec.settings.clear_site
    end
    after_each do
      Ktistec.settings.host = "https://test.test"
      Ktistec.settings.site = "Test"
    end

    describe "GET /" do
      it "renders a form" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/", headers
        expect(response.status_code).to eq(200)
        expect(XML.parse_html(response.body).xpath_nodes("//form[.//input[@name='host']][.//input[@name='site']]")).not_to be_empty
      end

      it "returns a template" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/", headers
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).as_h.keys).to have("host", "site")
      end
    end

    describe "POST /" do
      it "rerenders if host is invalid" do
        headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
        body = "host=foo_bar&site=Foo+Bar"
        post "/", headers, body
        expect(response.status_code).to eq(200)
        expect(XML.parse_html(response.body).xpath_nodes("//form/div[contains(@class,'error message')]/div").first).to match(/must have a scheme/)
      end

      it "rerenders if site is invalid" do
        headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
        body = "host=https://foo_bar&site="
        post "/", headers, body
        expect(response.status_code).to eq(200)
        expect(XML.parse_html(response.body).xpath_nodes("//form/div[contains(@class,'error message')]/div").first).to match(/must be present/)
      end

      it "rerenders if host is invalid" do
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        body = {host: "", site: ""}.to_json
        post "/", headers, body
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body)["errors"].as_h).to have_value(["name must be present"])
      end

      it "rerenders if site is invalid" do
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        body = {host: "", site: ""}.to_json
        post "/", headers, body
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body)["errors"].as_h).to have_value(["name must be present"])
      end

      it "sets host and redirects" do
        headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
        body = "host=https://foo_bar&site=Foo+Bar"
        expect{post "/", headers, body}.to change{Ktistec.settings.host}
        expect(response.status_code).to eq(302)
        expect(response.headers.to_a).to have({"Location", ["/"]})
      end

      it "sets site and redirects" do
        headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
        body = "host=https://foo_bar&site=Foo+Bar"
        expect{post "/", headers, body}.to change{Ktistec.settings.site}
        expect(response.status_code).to eq(302)
        expect(response.headers.to_a).to have({"Location", ["/"]})
      end

      it "sets host and redirects" do
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        body = {host: "https://foo_bar", site: "Foo Bar"}.to_json
        expect{post "/", headers, body}.to change{Ktistec.settings.host}
        expect(response.status_code).to eq(302)
        expect(response.headers.to_a).to have({"Location", ["/"]})
      end

      it "sets site and redirects" do
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        body = {host: "https://foo_bar", site: "Foo Bar"}.to_json
        expect{post "/", headers, body}.to change{Ktistec.settings.site}
        expect(response.status_code).to eq(302)
        expect(response.headers.to_a).to have({"Location", ["/"]})
      end
    end
  end

  context "on step 2 (create account)" do
    describe "GET /" do
      it "renders a form" do
        headers = HTTP::Headers{"Accept" => "text/html"}
        get "/", headers
        expect(response.status_code).to eq(200)
        expect(XML.parse_html(response.body).xpath_nodes("//form[.//input[@name='username']][.//input[@name='password']][.//input[@name='name']][.//input[@name='summary']]")).not_to be_empty
      end

      it "returns a template" do
        headers = HTTP::Headers{"Accept" => "application/json"}
        get "/", headers
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).as_h.keys).to have("username", "password", "name", "summary")
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
        body = "username=&password=a1!&name=&summary="
        post "/", headers, body
        expect(response.status_code).to eq(200)
        expect(XML.parse_html(response.body).xpath_nodes("//form/div[contains(@class,'error message')]/div").first).to match(/username is too short, password is too short/)
      end

      it "rerenders if params are invalid" do
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        body = {username: "", password: "a1!", name: "", summary: ""}.to_json
        post "/", headers, body
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body)["errors"].as_h).to eq({"username" => ["is too short"], "password" => ["is too short"]})
      end

      it "redirects and sets cookie" do
        headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
        body = "username=#{username}&password=#{password}&name=&summary="
        post "/", headers, body
        expect(response.status_code).to eq(302)
        expect(response.headers["Set-Cookie"]).to be_truthy
      end

      it "creates account" do
        headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
        body = "username=#{username}&password=#{password}&name=&summary="
        expect{post "/", headers, body}.to change{Account.count}.by(1)
      end

      it "creates actor" do
        headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
        body = "username=#{username}&password=#{password}&name=&summary="
        expect{post "/", headers, body}.to change{ActivityPub::Actor.count}.by(1)
      end

      it "associates account and actor" do
        headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
        body = "username=#{username}&password=#{password}&name=&summary="
        post "/", headers, body
        expect(Account.find(username: username).actor).not_to be_nil
      end

      it "returns token" do
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        body = {username: username, password: password, name: "", summary: ""}.to_json
        post "/", headers, body
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body)["jwt"]).to be_truthy
      end

      it "creates account" do
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        body = {username: username, password: password, name: "", summary: ""}.to_json
        expect{post "/", headers, body}.to change{Account.count}.by(1)
      end

      it "creates actor" do
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        body = {username: username, password: password, name: "", summary: ""}.to_json
        expect{post "/", headers, body}.to change{ActivityPub::Actor.count}.by(1)
      end

      it "associates account and actor" do
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        body = {username: username, password: password, name: "", summary: ""}.to_json
        post "/", headers, body
        expect(Account.find(username: username).actor).not_to be_nil
      end
    end
  end

  context "when requesting the home page" do
    let!(account) { register(username, password) }

    context "if unauthenticated" do
      describe "GET /" do
        it "renders a list of local actors" do
          headers = HTTP::Headers{"Accept" => "text/html"}
          get "/", headers
          expect(response.status_code).to eq(200)
          expect(XML.parse_html(response.body).xpath_nodes("//div[contains(@class,'card')]//a[contains(@href,'#{username}')]/@href")).to contain_exactly(/\/actors\/#{username}/)
        end

        it "renders a list of local actors" do
          headers = HTTP::Headers{"Accept" => "application/json"}
          get "/", headers
          expect(response.status_code).to eq(200)
          expect(JSON.parse(response.body)["items"].as_a).to have(/\/actors\/#{username}/)
        end
      end
    end

    context "if authenticated" do
      sign_in(as: account.username)

      describe "GET /" do
        it "redirects to the user's page" do
          headers = HTTP::Headers{"Accept" => "text/html"}
          get "/", headers
          expect(response.status_code).to eq(302)
          expect(response.headers.to_a).to have({"Location", ["/actors\/#{username}"]})
        end

        it "redirects to the user's page" do
          headers = HTTP::Headers{"Accept" => "application/json"}
          get "/", headers
          expect(response.status_code).to eq(302)
          expect(response.headers.to_a).to have({"Location", ["/actors\/#{username}"]})
        end
      end
    end

    describe "POST /" do
      it "returns 404" do
        headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
        post "/", headers
        expect(response.status_code).to eq(404)
      end

      it "returns 404" do
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        post "/", headers
        expect(response.status_code).to eq(404)
      end
    end
  end
end
