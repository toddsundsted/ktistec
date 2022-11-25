require "../../src/controllers/home"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe HomeController do
  setup_spec

  HTML_HEADERS = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
  JSON_HEADERS = HTTP::Headers{"Content-Type" => "application/json", "Accept" => "application/json"}

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
        get "/", HTML_HEADERS
        expect(response.status_code).to eq(200)
        expect(XML.parse_html(response.body).xpath_nodes("//form[.//input[@name='host']][.//input[@name='site']]")).not_to be_empty
      end

      it "returns a template" do
        get "/", JSON_HEADERS
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).as_h.keys).to have("host", "site")
      end
    end

    describe "POST /" do
      it "rerenders if host is invalid" do
        body = "host=foo_bar&site=Foo+Bar"
        post "/", HTML_HEADERS, body
        expect(response.status_code).to eq(422)
        expect(XML.parse_html(response.body).xpath_nodes("//form/div[contains(@class,'error message')]/div").first).to match(/must have a scheme/)
      end

      it "rerenders if site is invalid" do
        body = "host=https://foo_bar&site="
        post "/", HTML_HEADERS, body
        expect(response.status_code).to eq(422)
        expect(XML.parse_html(response.body).xpath_nodes("//form/div[contains(@class,'error message')]/div").first).to match(/must be present/)
      end

      it "rerenders if host is invalid" do
        body = {host: "", site: ""}.to_json
        post "/", JSON_HEADERS, body
        expect(response.status_code).to eq(422)
        expect(JSON.parse(response.body)["errors"].as_h).to have_value(["name must be present"])
      end

      it "rerenders if site is invalid" do
        body = {host: "", site: ""}.to_json
        post "/", JSON_HEADERS, body
        expect(response.status_code).to eq(422)
        expect(JSON.parse(response.body)["errors"].as_h).to have_value(["name must be present"])
      end

      it "sets host and redirects" do
        body = "host=https://foo_bar&site=Foo+Bar"
        expect{post "/", HTML_HEADERS, body}.to change{Ktistec.settings.host}
        expect(response.status_code).to eq(302)
        expect(response.headers.to_a).to have({"Location", ["/"]})
      end

      it "sets site and redirects" do
        body = "host=https://foo_bar&site=Foo+Bar"
        expect{post "/", HTML_HEADERS, body}.to change{Ktistec.settings.site}
        expect(response.status_code).to eq(302)
        expect(response.headers.to_a).to have({"Location", ["/"]})
      end

      it "sets host and redirects" do
        body = {host: "https://foo_bar", site: "Foo Bar"}.to_json
        expect{post "/", JSON_HEADERS, body}.to change{Ktistec.settings.host}
        expect(response.status_code).to eq(302)
        expect(response.headers.to_a).to have({"Location", ["/"]})
      end

      it "sets site and redirects" do
        body = {host: "https://foo_bar", site: "Foo Bar"}.to_json
        expect{post "/", JSON_HEADERS, body}.to change{Ktistec.settings.site}
        expect(response.status_code).to eq(302)
        expect(response.headers.to_a).to have({"Location", ["/"]})
      end
    end
  end

  context "on step 2 (create account)" do
    describe "GET /" do
      it "renders a form" do
        get "/", HTML_HEADERS
        expect(response.status_code).to eq(200)
        expect(XML.parse_html(response.body).xpath_nodes("//form[.//input[@name='username']][.//input[@name='password']][.//input[@name='name']][.//input[@name='summary']]")).not_to be_empty
      end

      it "returns a template" do
        get "/", JSON_HEADERS
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body).as_h.keys).to have("username", "password", "name", "summary")
      end
    end

    describe "POST /" do
      it "redirects if params are missing" do
        post "/", HTML_HEADERS
        expect(response.status_code).to eq(302)
        expect(response.headers.to_a).to have({"Location", ["/"]})
      end

      it "redirects if params are missing" do
        post "/", JSON_HEADERS
        expect(response.status_code).to eq(302)
        expect(response.headers.to_a).to have({"Location", ["/"]})
      end

      it "rerenders if params are invalid" do
        body = "username=&password=a1!&name=&summary=&timezone="
        post "/", HTML_HEADERS, body
        expect(response.status_code).to eq(422)
        expect(XML.parse_html(response.body).xpath_nodes("//form/div[contains(@class,'error message')]/div").first).to match(/username is too short, password is too short/)
      end

      it "rerenders if params are invalid" do
        body = {username: "", password: "a1!", name: "", summary: "", timezone: ""}.to_json
        post "/", JSON_HEADERS, body
        expect(response.status_code).to eq(422)
        expect(JSON.parse(response.body)["errors"].as_h).to eq({"username" => ["is too short"], "password" => ["is too short"]})
      end

      it "redirects and sets cookie" do
        body = "username=#{username}&password=#{password}&name=&summary=&timezone="
        post "/", HTML_HEADERS, body
        expect(response.status_code).to eq(302)
        expect(response.headers["Set-Cookie"]).to be_truthy
      end

      it "creates account" do
        body = "username=#{username}&password=#{password}&name=&summary=&timezone="
        expect{post "/", HTML_HEADERS, body}.to change{Account.count}.by(1)
      end

      it "creates actor" do
        body = "username=#{username}&password=#{password}&name=&summary=&timezone="
        expect{post "/", HTML_HEADERS, body}.to change{ActivityPub::Actor.count}.by(1)
      end

      it "associates account and actor" do
        body = "username=#{username}&password=#{password}&name=&summary=&timezone="
        post "/", HTML_HEADERS, body
        expect(Account.find(username: username).actor).not_to be_nil
      end

      it "returns token" do
        body = {username: username, password: password, name: "", summary: "", timezone: ""}.to_json
        post "/", JSON_HEADERS, body
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body)["jwt"]).to be_truthy
      end

      it "creates account" do
        body = {username: username, password: password, name: "", summary: "", timezone: ""}.to_json
        expect{post "/", JSON_HEADERS, body}.to change{Account.count}.by(1)
      end

      it "creates actor" do
        body = {username: username, password: password, name: "", summary: "", timezone: ""}.to_json
        expect{post "/", JSON_HEADERS, body}.to change{ActivityPub::Actor.count}.by(1)
      end

      it "associates account and actor" do
        body = {username: username, password: password, name: "", summary: "", timezone: ""}.to_json
        post "/", JSON_HEADERS, body
        expect(Account.find(username: username).actor).not_to be_nil
      end
    end
  end

  context "when requesting the home page" do
    let!(account) { register(username, password) }

    context "if unauthenticated" do
      describe "GET /" do
        it "renders a list of local actors" do
          get "/", HTML_HEADERS
          expect(response.status_code).to eq(200)
          expect(XML.parse_html(response.body).xpath_nodes("//div[contains(@class,'segments')]//a[contains(@href,'#{username}')]/@href")).to contain_exactly(/\/@#{username}/)
        end

        it "renders a list of local actors" do
          get "/", JSON_HEADERS
          expect(response.status_code).to eq(200)
          expect(JSON.parse(response.body)["items"].as_a).to have(/\/actors\/#{username}/)
        end

        let(actor) { account.actor }

        let_build(:object, attributed_to: author)
        let_build(:create, actor: author, object: object)
        let_build(:announce, actor: actor, object: object)

        context "when author is local" do
          let(author) { actor }

          pre_condition { expect(object.local?).to be_true }

          context "given a create" do
            before_each do
              put_in_outbox(author, create)
            end

            it "renders the object's create aspect" do
              get "/", HTML_HEADERS
              expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly("event activity-create")
            end
          end

          context "given an announce" do
            before_each do
              put_in_outbox(author, announce)
            end

            it "renders the object's announce aspect" do
              get "/", HTML_HEADERS
              expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly("event activity-announce")
            end
          end

          context "given a create and an announce" do
            before_each do
              put_in_outbox(author, create)
              put_in_outbox(author, announce)
            end

            it "renders the object's create aspect" do
              get "/", HTML_HEADERS
              expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly("event activity-create")
            end
          end
        end

        context "when author is remote" do
          let_build(:actor, named: :author)

          pre_condition { expect(object.local?).to be_false }

          context "given a create and an announce" do
            before_each do
              put_in_inbox(actor, create)
              put_in_outbox(actor, announce)
            end

            it "renders the object's announce aspect" do
              get "/", HTML_HEADERS
              expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly("event activity-announce")
            end
          end
        end
      end
    end

    context "if authenticated" do
      sign_in(as: account.username)

      describe "GET /" do
        it "redirects to the user's page" do
          get "/", HTML_HEADERS
          expect(response.status_code).to eq(302)
          expect(response.headers.to_a).to have({"Location", ["/actors\/#{username}"]})
        end

        it "redirects to the user's page" do
          get "/", JSON_HEADERS
          expect(response.status_code).to eq(302)
          expect(response.headers.to_a).to have({"Location", ["/actors\/#{username}"]})
        end
      end
    end

    describe "POST /" do
      it "returns 404" do
        post "/", HTML_HEADERS
        expect(response.status_code).to eq(404)
      end

      it "returns 404" do
        post "/", JSON_HEADERS
        expect(response.status_code).to eq(404)
      end
    end
  end
end
