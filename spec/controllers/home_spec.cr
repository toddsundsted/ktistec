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
        expect { post "/", HTML_HEADERS, body }.to change { Ktistec.settings.host }
        expect(response.status_code).to eq(302)
        expect(response.headers.to_a).to have({"Location", ["/"]})
      end

      it "sets site and redirects" do
        body = "host=https://foo_bar&site=Foo+Bar"
        expect { post "/", HTML_HEADERS, body }.to change { Ktistec.settings.site }
        expect(response.status_code).to eq(302)
        expect(response.headers.to_a).to have({"Location", ["/"]})
      end

      it "sets host and redirects" do
        body = {host: "https://foo_bar", site: "Foo Bar"}.to_json
        expect { post "/", JSON_HEADERS, body }.to change { Ktistec.settings.host }
        expect(response.status_code).to eq(302)
        expect(response.headers.to_a).to have({"Location", ["/"]})
      end

      it "sets site and redirects" do
        body = {host: "https://foo_bar", site: "Foo Bar"}.to_json
        expect { post "/", JSON_HEADERS, body }.to change { Ktistec.settings.site }
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
        body = "username=&password=a1!&name=&summary=&timezone=&language=en&type=Invalid"
        post "/", HTML_HEADERS, body
        expect(response.status_code).to eq(422)
        expect(XML.parse_html(response.body).xpath_nodes("//form/div[contains(@class,'error message')]/div").first).to match(/username is too short, password is too short, type is not valid/)
      end

      it "rerenders if params are invalid" do
        body = {username: "", password: "a1!", name: "", summary: "", timezone: "", language: "en", type: "Invalid"}.to_json
        post "/", JSON_HEADERS, body
        expect(response.status_code).to eq(422)
        expect(JSON.parse(response.body)["errors"].as_h).to eq({"username" => ["is too short"], "password" => ["is too short"], "type" => ["is not valid"]})
      end

      let(query_string) { "username=#{username}&password=#{password}&name=&summary=&timezone=&language=en" }

      it "redirects and sets cookie" do
        post "/", HTML_HEADERS, query_string
        expect(response.status_code).to eq(302)
        expect(response.headers["Set-Cookie"]).to be_truthy
      end

      it "creates account" do
        expect { post "/", HTML_HEADERS, query_string }.to change { Account.count }.by(1)
      end

      it "creates actor of type ActivityPub::Actor::Person by default" do
        post "/", HTML_HEADERS, query_string
        actor = Account.find(username: username).actor
        expect(actor.class).to eq(ActivityPub::Actor::Person)
        expect(actor.type).to eq("ActivityPub::Actor::Person")
      end

      it "creates actor of type ActivityPub::Actor::Organization" do
        post "/", HTML_HEADERS, query_string + "&type=ActivityPub::Actor::Organization"
        actor = Account.find(username: username).actor
        expect(actor.class).to eq(ActivityPub::Actor)
        expect(actor.type).to eq("ActivityPub::Actor::Organization")
      end

      it "associates account and actor" do
        post "/", HTML_HEADERS, query_string
        expect(Account.find(username: username).actor).not_to be_nil
      end

      let(json_string) { {username: username, password: password, name: "", summary: "", timezone: "", language: "en"}.to_json }

      it "returns token" do
        post "/", JSON_HEADERS, json_string
        expect(response.status_code).to eq(200)
        expect(JSON.parse(response.body)["jwt"]).to be_truthy
      end

      it "creates account" do
        expect { post "/", JSON_HEADERS, json_string }.to change { Account.count }.by(1)
      end

      it "creates actor of type ActivityPub::Actor::Person by default" do
        post "/", JSON_HEADERS, json_string
        actor = Account.find(username: username).actor
        expect(actor.class).to eq(ActivityPub::Actor::Person)
        expect(actor.type).to eq("ActivityPub::Actor::Person")
      end

      it "creates actor of type ActivityPub::Actor::Organization" do
        post "/", JSON_HEADERS, JSON.parse(json_string).as_h.merge({"type" => "ActivityPub::Actor::Organization"}).to_json
        actor = Account.find(username: username).actor
        expect(actor.class).to eq(ActivityPub::Actor)
        expect(actor.type).to eq("ActivityPub::Actor::Organization")
      end

      it "associates account and actor" do
        post "/", JSON_HEADERS, json_string
        expect(Account.find(username: username).actor).not_to be_nil
      end
    end
  end

  context "when requesting the home page" do
    let!(account) { register(username, password) }

    context "if unauthenticated" do
      describe "GET /" do
        it "succeeds" do
          get "/", HTML_HEADERS
          expect(response.status_code).to eq(200)
          # no local actors, only posts on this page
        end

        after_each { Ktistec.set_default_settings }

        context "without a site description" do
          before_each { Ktistec.settings.clear_description }

          it "does not display site description" do
            get "/", HTML_HEADERS
            expect(XML.parse_html(response.body).xpath_nodes("//div[contains(@class,'ui segment event')]")).to be_empty
          end
        end

        context "with a site description" do
          before_each { Ktistec.settings.assign({"description" => "<p>Welcome to our server!</p>"}).save }

          it "displays site description" do
            get "/", HTML_HEADERS
            expect(XML.parse_html(response.body).xpath_nodes("//div[contains(@class,'ui segment event')]//p").first).to eq("Welcome to our server!")
          end
        end

        it "includes RSS feed discovery link in HTML head" do
          get "/", HTML_HEADERS
          expect(response.status_code).to eq(200)
          html = XML.parse_html(response.body)
          rss_link = html.xpath_node("//link[@rel='alternate'][@type='application/rss+xml'][@href='/feed.rss']")
          expect(rss_link.try(&.["title"])).to eq("Test: RSS Feed")
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
              expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly(/event activity-create/)
            end
          end

          context "given an announce" do
            before_each do
              put_in_outbox(author, announce)
            end

            it "renders the object's announce aspect" do
              get "/", HTML_HEADERS
              expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly(/event activity-announce/)
            end
          end

          context "given a create and an announce" do
            before_each do
              put_in_outbox(author, create)
              put_in_outbox(author, announce)
            end

            it "renders the object's create aspect" do
              get "/", HTML_HEADERS
              expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly(/event activity-create/)
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
              expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@class")).to contain_exactly(/event activity-announce/)
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
          expect(response.headers.to_a).to have({"Location", ["/actors/#{username}"]})
        end

        it "redirects to the user's page" do
          get "/", JSON_HEADERS
          expect(response.status_code).to eq(302)
          expect(response.headers.to_a).to have({"Location", ["/actors/#{username}"]})
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

  describe "GET /feed.rss" do
    let!(account) { register(username, password) }

    it "returns correct content type" do
      get "/feed.rss"
      expect(response.status_code).to eq(200)
      expect(response.headers["Content-Type"]).to eq("application/rss+xml; charset=utf-8")
    end

    it "returns valid RSS" do
      get "/feed.rss"
      expect(response.status_code).to eq(200)
      xml = XML.parse(response.body)
      expect(xml.xpath_node("//rss")).to_not be_nil
      expect(xml.xpath_node("//channel")).to_not be_nil
    end

    let_build(:create)

    it "includes public posts" do
      put_in_outbox(account.actor, create)

      get "/feed.rss", HTML_HEADERS
      expect(response.status_code).to eq(200)
      xml = XML.parse(response.body)
      expect(xml.xpath_nodes("//item")).to_not be_empty
      expect(xml.xpath_node("//item/title")).to_not be_nil
      expect(xml.xpath_node("//item/link")).to_not be_nil
      expect(xml.xpath_node("//item/description")).to_not be_nil
      expect(xml.xpath_node("//item/pubDate")).to_not be_nil
      expect(xml.xpath_node("//item/guid")).to_not be_nil
    end
  end
end
