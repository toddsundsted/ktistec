require "../../src/controllers/feeds"
require "../../src/services/feed/backend/criteria"

require "../spec_helper/controller"
require "../spec_helper/factory"

Spectator.describe FeedsController do
  setup_spec

  ACCEPT_HTML  = HTTP::Headers{"Accept" => "text/html"}
  ACCEPT_JSON  = HTTP::Headers{"Accept" => "application/json"}
  FORM_HEADERS = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
  JSON_HEADERS = HTTP::Headers{"Content-Type" => "application/json", "Accept" => "application/json"}

  around_each do |proc|
    saved = Rules::View.registry.dup
    begin
      proc.call
    ensure
      Rules::View.registry.clear
      Rules::View.registry.concat(saved)
    end
  end

  let(actor) { register.actor }

  describe "GET /actors/:username/feeds" do
    it "returns 401 if not authorized" do
      get "/actors/#{actor.username}/feeds", ACCEPT_HTML
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      get "/actors/#{actor.username}/feeds", ACCEPT_JSON
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "returns 404 if the account does not exist" do
        get "/actors/missing/feeds", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if the account does not exist" do
        get "/actors/missing/feeds", ACCEPT_JSON
        expect(response.status_code).to eq(404)
      end

      it "returns 404 for a different account" do
        get "/actors/#{register.actor.username}/feeds", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 for a different account" do
        get "/actors/#{register.actor.username}/feeds", ACCEPT_JSON
        expect(response.status_code).to eq(404)
      end

      it "succeeds" do
        get "/actors/#{actor.username}/feeds", ACCEPT_HTML
        expect(response.status_code).to eq(200)
      end

      it "succeeds" do
        get "/actors/#{actor.username}/feeds", ACCEPT_JSON
        expect(response.status_code).to eq(200)
      end

      it "renders the empty page" do
        get "/actors/#{actor.username}/feeds", ACCEPT_HTML
        expect(response.body).to contain("don't have any feeds")
      end

      it "renders the empty collection" do
        get "/actors/#{actor.username}/feeds", ACCEPT_JSON
        expect(JSON.parse(response.body)["feeds"].as_a).to be_empty
      end

      context "given a feed" do
        let_create!(
          :feed,
          named: mixed,
          owner: actor,
          name: "Robotics",
          params: JSON.parse(%({"hashtags":{"any":["cnc"]},"mentions":{"none":["bob@host"]}})).as_h,
        )

        macro entry
          JSON.parse(response.body)["feeds"].as_a.find! { |f| f["id"].as_i64 == mixed.id }
        end

        it "links the feed name to the feed" do
          get "/actors/#{actor.username}/feeds", ACCEPT_HTML
          href = XML.parse_html(response.body).xpath_nodes("//a[contains(@class,'header')][text()='Robotics']/@href").first?
          expect(href.try(&.text)).to eq("/actors/#{actor.username}/feeds/#{mixed.id}")
        end

        it "renders the feed id" do
          get "/actors/#{actor.username}/feeds", ACCEPT_JSON
          expect(entry["id"].as_i64).to eq(mixed.id)
        end

        it "renders the feed name" do
          get "/actors/#{actor.username}/feeds", ACCEPT_JSON
          expect(entry["name"].as_s).to eq("Robotics")
        end

        it "renders the feed href" do
          get "/actors/#{actor.username}/feeds", ACCEPT_JSON
          expect(entry["href"].as_s).to eq("/actors/#{actor.username}/feeds/#{mixed.id}")
        end

        macro terms(kind)
          entry["summary"][{{kind}}].as_a.map { |term| {term["type"].as_s, term["label"].as_s} }
        end

        it "renders the terms" do
          get "/actors/#{actor.username}/feeds", ACCEPT_HTML
          expect(response.body).to contain("#cnc", "@bob@host")
        end

        it "renders the any-selector terms" do
          get "/actors/#{actor.username}/feeds", ACCEPT_JSON
          expect(terms("any")).to eq([{"hashtag", "#cnc"}])
        end

        it "renders the none-selector terms" do
          get "/actors/#{actor.username}/feeds", ACCEPT_JSON
          expect(terms("none")).to eq([{"mention", "@bob@host"}])
        end

        it "renders the term count" do
          get "/actors/#{actor.username}/feeds", ACCEPT_HTML
          expect(response.body).to contain("2 terms")
        end

        it "renders the term count" do
          get "/actors/#{actor.username}/feeds", ACCEPT_JSON
          expect(entry["terms"].as_i).to eq(2)
        end

        it "renders no posts" do
          get "/actors/#{actor.username}/feeds", ACCEPT_HTML
          expect(response.body).to contain("no posts")
        end

        it "renders no posts" do
          get "/actors/#{actor.username}/feeds", ACCEPT_JSON
          expect(entry["posts"].as_i).to eq(0)
        end

        context "given posts" do
          let_create(:object)

          before_each { put_in_feed(mixed, object) }

          it "renders the post count" do
            get "/actors/#{actor.username}/feeds", ACCEPT_HTML
            expect(response.body).to contain("1 post")
          end

          it "renders the post count" do
            get "/actors/#{actor.username}/feeds", ACCEPT_JSON
            expect(entry["posts"].as_i).to eq(1)
          end
        end

        it "renders the feed as published" do
          get "/actors/#{actor.username}/feeds", ACCEPT_HTML
          expect(response.body).to contain(mixed.name)
          expect(response.body).not_to contain("Draft")
        end

        it "renders the feed as published" do
          get "/actors/#{actor.username}/feeds", ACCEPT_JSON
          expect(entry["draft"].as_bool).to be_false
        end

        context "that is draft" do
          before_each { mixed.assign(draft: true).save }

          it "renders the empty page" do
            get "/actors/#{actor.username}/feeds", ACCEPT_HTML
            expect(response.body).to contain("don't have any feeds")
          end

          it "renders the empty collection" do
            get "/actors/#{actor.username}/feeds", ACCEPT_JSON
            expect(JSON.parse(response.body)["feeds"].as_a).to be_empty
          end

          context "and drafts are included" do
            it "renders the feed as a draft" do
              get "/actors/#{actor.username}/feeds?include=drafts", ACCEPT_HTML
              expect(response.body).to contain("Draft")
            end

            it "renders the feed as a draft" do
              get "/actors/#{actor.username}/feeds?include=drafts", ACCEPT_JSON
              expect(entry["draft"].as_bool).to be_true
            end

            it "renders nothing in preview" do
              get "/actors/#{actor.username}/feeds?include=drafts", ACCEPT_HTML
              expect(response.body).to contain("nothing in preview")
            end

            context "and the draft has matches" do
              let_create(:object)

              before_each { put_in_feed(mixed, object) }

              it "renders the preview size" do
                get "/actors/#{actor.username}/feeds?include=drafts", ACCEPT_HTML
                expect(response.body).to contain("1 post in preview")
              end
            end

            context "and the draft replaces a published feed" do
              let_create!(:feed, named: replaced, owner: actor, name: "Replaced")

              before_each { mixed.assign(copy_of: replaced.id).save }

              it "lists the published feed alongside the draft" do
                get "/actors/#{actor.username}/feeds?include=drafts", ACCEPT_HTML
                expect(response.body).to contain("Replaced", "Robotics")
              end

              it "lists the published feed alongside the draft" do
                get "/actors/#{actor.username}/feeds?include=drafts", ACCEPT_JSON
                feeds = JSON.parse(response.body)["feeds"].as_a.map(&.["name"].as_s)
                expect(feeds).to contain_exactly("Replaced", "Robotics")
              end

              it "names the feed it replaces" do
                get "/actors/#{actor.username}/feeds?include=drafts", ACCEPT_HTML
                expect(response.body).to contain("Draft of Replaced")
              end
            end
          end
        end
      end

      context "given two feeds" do
        let_create!(:feed, named: first_feed, owner: actor, name: "First")
        let_create!(:feed, named: second_feed, owner: actor, name: "Second")

        let_create(:object, named: first_object)
        let_create(:object, named: second_object)

        macro names
          JSON.parse(response.body)["feeds"].as_a.map { |f| f["name"].as_s }
        end

        it "sorts the more recently created feed first" do
          get "/actors/#{actor.username}/feeds", ACCEPT_JSON
          expect(names).to eq(["Second", "First"])
        end

        context "and the first feed has posts" do
          before_each { put_in_feed(first_feed, first_object, at: 2.hours.ago) }

          it "sorts the empty feed first" do
            get "/actors/#{actor.username}/feeds", ACCEPT_JSON
            expect(names).to eq(["Second", "First"])
          end
        end

        context "and the second feed has posts" do
          before_each { put_in_feed(second_feed, second_object, at: 2.hours.ago) }

          it "sorts the empty feed first" do
            get "/actors/#{actor.username}/feeds", ACCEPT_JSON
            expect(names).to eq(["First", "Second"])
          end
        end

        context "and neither feed has posts" do
          it "sorts the more recently created feed first" do
            get "/actors/#{actor.username}/feeds", ACCEPT_JSON
            expect(names).to eq(["Second", "First"])
          end
        end

        context "and both feeds have posts" do
          before_each { put_in_feed(second_feed, second_object, at: 2.hours.ago) }

          context "and the first feed's post is newer" do
            before_each { put_in_feed(first_feed, first_object, at: 1.hour.ago) }

            it "sorts the first feed first" do
              get "/actors/#{actor.username}/feeds", ACCEPT_JSON
              expect(names).to eq(["First", "Second"])
            end
          end

          context "and the first feed's post is older" do
            before_each { put_in_feed(first_feed, first_object, at: 3.hours.ago) }

            it "sorts the first feed last" do
              get "/actors/#{actor.username}/feeds", ACCEPT_JSON
              expect(names).to eq(["Second", "First"])
            end
          end
        end

        context "and both have posts that arrived at the same instant" do
          let(at) { 2.hours.ago }

          before_each do
            put_in_feed(first_feed, first_object, at: at)
            put_in_feed(second_feed, second_object, at: at)
          end

          it "sorts the more recently created feed first" do
            get "/actors/#{actor.username}/feeds", ACCEPT_JSON
            expect(names).to eq(["Second", "First"])
          end
        end
      end
    end
  end

  describe "GET /actors/:username/feeds/:id" do
    let_create!(:feed, owner: actor)

    it "returns 401 if not authorized" do
      get "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_HTML
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      get "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_JSON
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "returns 404 if not found" do
        get "/actors/missing/feeds/#{feed.id}", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if not found" do
        get "/actors/missing/feeds/#{feed.id}", ACCEPT_JSON
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if different account" do
        get "/actors/#{register.actor.username}/feeds/#{feed.id}", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if different account" do
        get "/actors/#{register.actor.username}/feeds/#{feed.id}", ACCEPT_JSON
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if the feed does not exist" do
        get "/actors/#{actor.username}/feeds/999999", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if the feed does not exist" do
        get "/actors/#{actor.username}/feeds/999999", ACCEPT_JSON
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if the feed id is not numeric" do
        get "/actors/#{actor.username}/feeds/abc", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if the feed id is not numeric" do
        get "/actors/#{actor.username}/feeds/abc", ACCEPT_JSON
        expect(response.status_code).to eq(404)
      end

      context "given a feed owned by another actor" do
        let_create!(:feed, named: other)

        it "returns 404" do
          get "/actors/#{actor.username}/feeds/#{other.id}", ACCEPT_HTML
          expect(response.status_code).to eq(404)
        end

        it "returns 404" do
          get "/actors/#{actor.username}/feeds/#{other.id}", ACCEPT_JSON
          expect(response.status_code).to eq(404)
        end
      end

      it "succeeds" do
        get "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_HTML
        expect(response.status_code).to eq(200)
      end

      it "succeeds" do
        get "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_JSON
        expect(response.status_code).to eq(200)
      end

      context "that is a draft" do
        before_each { feed.assign(draft: true).save }

        it "succeeds" do
          get "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_HTML
          expect(response.status_code).to eq(302)
        end

        it "succeeds" do
          get "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_JSON
          expect(response.status_code).to eq(302)
        end

        it "redirects to the editor" do
          get "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_HTML
          expect(response.headers["Location"]).to eq("/actors/#{actor.username}/feeds/#{feed.id}/edit")
        end

        it "redirects to the editor" do
          get "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_JSON
          expect(response.headers["Location"]).to eq("/actors/#{actor.username}/feeds/#{feed.id}/edit")
        end
      end

      context "given objects in the feed" do
        let_create(:object, named: earlier)
        let_create(:object, named: later)

        before_each do
          put_in_feed(feed, earlier)
          put_in_feed(feed, later)
        end

        it "renders the objects most recently arrived first" do
          get "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_HTML
          expect(response.status_code).to eq(200)
          expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id")).to contain_exactly("object-#{later.id}", "object-#{earlier.id}")
        end

        it "renders the objects most recently arrived first" do
          get "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_JSON
          expect(response.status_code).to eq(200)
          expect(JSON.parse(response.body).dig("first", "orderedItems").as_a.map(&.as_s)).to eq([later.iri, earlier.iri])
        end

        it "paginates the results" do
          get "/actors/#{actor.username}/feeds/#{feed.id}?limit=1", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id")).to contain_exactly("object-#{later.id}")
          expect(XML.parse_html(response.body).xpath_nodes("//nav[contains(@class,'pagination')]//a/@href")).to contain(/max-id=#{later.id}/)
        end

        it "paginates the results" do
          get "/actors/#{actor.username}/feeds/#{feed.id}?limit=1", ACCEPT_JSON
          expect(JSON.parse(response.body).dig("first", "orderedItems").as_a.map(&.as_s)).to eq([later.iri])
        end

        it "paginates the results" do
          get "/actors/#{actor.username}/feeds/#{feed.id}?max_id=#{later.id}&limit=1", ACCEPT_JSON
          expect(JSON.parse(response.body).dig("orderedItems").as_a.map(&.as_s)).to eq([earlier.iri])
        end
      end
    end
  end

  macro form_fields(*names)
    {
      {% for name in names %}
        body.xpath_string("string(//form//input[@name='{{name.id}}']/@value|//form//textarea[@name='{{name.id}}'])"),
      {% end %}
    }
  end

  macro json_fields(*names)
    {
      {% for name in names %}
        body["{{name.id}}"].as_s?,
      {% end %}
    }
  end

  describe "GET /actors/:username/feeds/new" do
    it "returns 401 if not authorized" do
      get "/actors/#{actor.username}/feeds/new", ACCEPT_HTML
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      get "/actors/#{actor.username}/feeds/new", ACCEPT_JSON
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "returns 404 for a different account" do
        get "/actors/#{register.actor.username}/feeds/new", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 for a different account" do
        get "/actors/#{register.actor.username}/feeds/new", ACCEPT_JSON
        expect(response.status_code).to eq(404)
      end

      it "succeeds" do
        get "/actors/#{actor.username}/feeds/new", ACCEPT_HTML
        expect(response.status_code).to eq(200)
      end

      it "succeeds" do
        get "/actors/#{actor.username}/feeds/new", ACCEPT_JSON
        expect(response.status_code).to eq(200)
      end

      it "renders the form" do
        get "/actors/#{actor.username}/feeds/new", ACCEPT_HTML
        body = XML.parse_html(response.body)
        expect(form_fields("name", "any", "all", "none")).to eq({"", "", "", ""})
      end

      it "renders the representation" do
        get "/actors/#{actor.username}/feeds/new", ACCEPT_JSON
        body = JSON.parse(response.body)
        expect(json_fields("name", "any", "all", "none")).to eq({"", "", "", ""})
      end
    end
  end

  # the state transition diagram in feeds.cr documents the behavior of
  # this endpoint

  describe "POST /actors/:username/feeds" do
    it "returns 401 if not authorized" do
      post "/actors/#{actor.username}/feeds", FORM_HEADERS, "name=Robotics&any=%23cnc"
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      post "/actors/#{actor.username}/feeds", JSON_HEADERS, %({"name":"Robotics","any":"#cnc"})
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "returns 404 for a different account" do
        post "/actors/#{register.actor.username}/feeds", FORM_HEADERS, "name=Robotics&any=%23cnc"
        expect(response.status_code).to eq(404)
      end

      it "returns 404 for a different account" do
        post "/actors/#{register.actor.username}/feeds", JSON_HEADERS, %({"name":"Robotics","any":"#cnc"})
        expect(response.status_code).to eq(404)
      end

      it "returns 413 if the body is too large" do
        post "/actors/#{actor.username}/feeds", FORM_HEADERS, "name=Robotics&any=#{"x" * FeedsController::MAX_REQUEST_BYTES}"
        expect(response.status_code).to eq(413)
      end

      it "returns 413 if the body is too large" do
        post "/actors/#{actor.username}/feeds", JSON_HEADERS, %({"name":"Robotics","any":"#{"x" * FeedsController::MAX_REQUEST_BYTES}"})
        expect(response.status_code).to eq(413)
      end

      it "creates a feed" do
        expect { post "/actors/#{actor.username}/feeds", FORM_HEADERS, "name=Robotics&any=%23cnc" }
          .to change { Feed.count }.by(1)
      end

      it "creates a feed" do
        expect { post "/actors/#{actor.username}/feeds", JSON_HEADERS, %({"name":"Robotics","any":"#cnc"}) }
          .to change { Feed.count }.by(1)
      end

      def robotics_feed
        Feed.find(name: "Robotics")
      end

      it "translates the criteria into params" do
        post "/actors/#{actor.username}/feeds", FORM_HEADERS, "name=Robotics&any=%23cnc%0A3d+print&none=%40bob%40host"
        expect(robotics_feed.params).to eq(JSON.parse(%({"keywords":{"any":["3d print"]},"hashtags":{"any":["cnc"]},"mentions":{"none":["bob@host"]}})).as_h)
      end

      it "translates the criteria into params" do
        post "/actors/#{actor.username}/feeds", JSON_HEADERS, %({"name":"Robotics","any":"#cnc\\n3d print","none":"@bob@host"})
        expect(robotics_feed.params).to eq(JSON.parse(%({"keywords":{"any":["3d print"]},"hashtags":{"any":["cnc"]},"mentions":{"none":["bob@host"]}})).as_h)
      end

      it "does not mark the feed as a draft" do
        post "/actors/#{actor.username}/feeds", FORM_HEADERS, "name=Robotics&any=%23cnc"
        expect(robotics_feed.draft).to be_false
      end

      it "does not mark the feed as a draft" do
        post "/actors/#{actor.username}/feeds", JSON_HEADERS, %({"name":"Robotics","any":"#cnc"})
        expect(robotics_feed.draft).to be_false
      end

      it "registers the feed's view" do
        post "/actors/#{actor.username}/feeds", FORM_HEADERS, "name=Robotics&any=%23cnc"
        expect(Rules::View.registry.map(&.type)).to contain(robotics_feed.feed_type)
      end

      it "registers the feed's view" do
        post "/actors/#{actor.username}/feeds", JSON_HEADERS, %({"name":"Robotics","any":"#cnc"})
        expect(Rules::View.registry.map(&.type)).to contain(robotics_feed.feed_type)
      end

      it "succeeds" do
        post "/actors/#{actor.username}/feeds", FORM_HEADERS, "name=Robotics&any=%23cnc"
        expect(response.status_code).to eq(302)
      end

      it "succeeds" do
        post "/actors/#{actor.username}/feeds", JSON_HEADERS, %({"name":"Robotics","any":"#cnc"})
        expect(response.status_code).to eq(201)
      end

      it "redirects to the index" do
        post "/actors/#{actor.username}/feeds", FORM_HEADERS, "name=Robotics&any=%23cnc"
        expect(response.headers["Location"]).to eq("/actors/#{actor.username}/feeds")
      end

      it "returns the feed's location" do
        post "/actors/#{actor.username}/feeds", JSON_HEADERS, %({"name":"Robotics","any":"#cnc"})
        expect(response.headers["Location"]).to eq("/actors/#{actor.username}/feeds/#{robotics_feed.id}")
      end

      context "given a blank name" do
        it "does not create a feed" do
          expect { post "/actors/#{actor.username}/feeds", FORM_HEADERS, "name=&any=%23cnc" }
            .not_to change { Feed.count }
        end

        it "does not create a feed" do
          expect { post "/actors/#{actor.username}/feeds", JSON_HEADERS, %({"name":"","any":"#cnc"}) }
            .not_to change { Feed.count }
        end

        it "returns 422" do
          post "/actors/#{actor.username}/feeds", FORM_HEADERS, "name=&any=%23cnc"
          expect(response.status_code).to eq(422)
        end

        it "returns 422" do
          post "/actors/#{actor.username}/feeds", JSON_HEADERS, %({"name":"","any":"#cnc"})
          expect(response.status_code).to eq(422)
        end

        it "returns errors" do
          post "/actors/#{actor.username}/feeds", FORM_HEADERS, "name=&any=%23cnc"
          message = XML.parse_html(response.body).xpath_nodes("//div[contains(@class,'error message')]").first?
          expect(message.try(&.text)).to contain("name can't be blank")
        end

        it "returns errors" do
          post "/actors/#{actor.username}/feeds", JSON_HEADERS, %({"name":"","any":"#cnc"})
          errors = JSON.parse(response.body)["errors"].as_h
          expect(errors["name"].as_a).to contain("can't be blank")
        end
      end

      context "given no positive criteria" do
        it "returns 422" do
          post "/actors/#{actor.username}/feeds", FORM_HEADERS, "name=Robotics&none=%23spam"
          expect(response.status_code).to eq(422)
        end

        it "returns 422" do
          post "/actors/#{actor.username}/feeds", JSON_HEADERS, %({"name":"Robotics","none":"#spam"})
          expect(response.status_code).to eq(422)
        end

        it "returns errors" do
          post "/actors/#{actor.username}/feeds", FORM_HEADERS, "name=Robotics&none=%23spam"
          message = XML.parse_html(response.body).xpath_nodes("//div[contains(@class,'error message')]").first?
          expect(message.try(&.text)).to contain("Add at least one keyword, #hashtag, or @mention.")
        end

        it "returns errors" do
          post "/actors/#{actor.username}/feeds", JSON_HEADERS, %({"name":"Robotics","none":"#spam"})
          errors = JSON.parse(response.body)["errors"].as_h
          expect(errors[""].as_a).to contain("Add at least one keyword, #hashtag, or @mention.")
        end
      end

      context "given a malformed term among valid terms" do
        it "names the offending term" do
          post "/actors/#{actor.username}/feeds", FORM_HEADERS, "name=Robotics&any=resin%0A%40bob%40h%40x%0Awood"
          message = XML.parse_html(response.body).xpath_nodes("//div[contains(@class,'error message')]").first?
          expect(message.try(&.text)).to contain(%("@bob@h@x" isn't a single mention. Put each @user@host.com on its own line, or drop the "@" to match it as a keyword.))
        end

        it "names the offending term" do
          post "/actors/#{actor.username}/feeds", JSON_HEADERS, %({"name":"Robotics","any":"resin\\n@bob@h@x\\nwood"})
          errors = JSON.parse(response.body)["errors"].as_h
          expect(errors[""].as_a).to contain(%("@bob@h@x" isn't a single mention. Put each @user@host.com on its own line, or drop the "@" to match it as a keyword.))
        end

        it "renders the terms in the order they were entered" do
          post "/actors/#{actor.username}/feeds", FORM_HEADERS, "name=Robotics&any=resin%0A%40bob%40h%40x%0Awood"
          body = XML.parse_html(response.body)
          expect(form_fields("any").first).to eq("resin\n@bob@h@x\nwood")
        end

        it "renders the terms in the order they were entered" do
          post "/actors/#{actor.username}/feeds", JSON_HEADERS, %({"name":"Robotics","any":"resin\\n@bob@h@x\\nwood"})
          body = JSON.parse(response.body)
          expect(json_fields("any").first).to eq("resin\n@bob@h@x\nwood")
        end
      end

      context "given a preview request" do
        let_create(:object, named: hit, content: "<p>cnc milling</p>")
        let_create(:create, named: hit_create, object: hit)

        before_each { put_in_inbox(actor, hit_create) }

        def preview_form
          "name=Robotics&any=cnc&preview=1"
        end

        def preview_json
          %({"name":"Robotics","any":"cnc","preview":"1"})
        end

        it "creates a feed" do
          expect { post "/actors/#{actor.username}/feeds", FORM_HEADERS, preview_form }
            .to change { Feed.count }.by(1)
        end

        it "creates a feed" do
          expect { post "/actors/#{actor.username}/feeds", JSON_HEADERS, preview_json }
            .to change { Feed.count }.by(1)
        end

        it "marks the feed as a draft" do
          post "/actors/#{actor.username}/feeds", FORM_HEADERS, preview_form
          expect(robotics_feed.draft).to be_true
        end

        it "marks the feed as a draft" do
          post "/actors/#{actor.username}/feeds", JSON_HEADERS, preview_json
          expect(robotics_feed.draft).to be_true
        end

        it "does not register the feed's view" do
          post "/actors/#{actor.username}/feeds", FORM_HEADERS, preview_form
          expect(Rules::View.registry.map(&.type)).not_to contain(robotics_feed.feed_type)
        end

        it "does not register the feed's view" do
          post "/actors/#{actor.username}/feeds", JSON_HEADERS, preview_json
          expect(Rules::View.registry.map(&.type)).not_to contain(robotics_feed.feed_type)
        end

        it "succeeds" do
          post "/actors/#{actor.username}/feeds", FORM_HEADERS, preview_form
          expect(response.status_code).to eq(302)
        end

        it "succeeds" do
          post "/actors/#{actor.username}/feeds", JSON_HEADERS, preview_json
          expect(response.status_code).to eq(302)
        end

        it "redirects to the draft's editor" do
          post "/actors/#{actor.username}/feeds", FORM_HEADERS, preview_form
          expect(response.headers["Location"]).to eq("/actors/#{actor.username}/feeds/#{robotics_feed.id}/edit")
        end

        it "redirects to the draft's editor" do
          post "/actors/#{actor.username}/feeds", JSON_HEADERS, preview_json
          expect(response.headers["Location"]).to eq("/actors/#{actor.username}/feeds/#{robotics_feed.id}/edit")
        end

        it "adds the matching post to the window" do
          post "/actors/#{actor.username}/feeds", FORM_HEADERS, preview_form
          get "/actors/#{actor.username}/feeds/#{robotics_feed.id}/edit", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id")).to contain("object-#{hit.id}")
        end

        it "adds the matching post to the window" do
          post "/actors/#{actor.username}/feeds", JSON_HEADERS, preview_json
          get "/actors/#{actor.username}/feeds/#{robotics_feed.id}/edit", ACCEPT_JSON
          expect(JSON.parse(response.body)["matches"].as_a.map(&.as_i64)).to contain(hit.id)
        end
      end
    end
  end

  describe "GET /actors/:username/feeds/:id/edit" do
    let_create!(:feed, owner: actor, name: "Robotics", params: JSON.parse(%({"hashtags":{"any":["cnc"]}})).as_h)

    it "returns 401 if not authorized" do
      get "/actors/#{actor.username}/feeds/#{feed.id}/edit", ACCEPT_HTML
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      get "/actors/#{actor.username}/feeds/#{feed.id}/edit", ACCEPT_JSON
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "returns 404 for a different account" do
        get "/actors/#{register.actor.username}/feeds/#{feed.id}/edit", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 for a different account" do
        get "/actors/#{register.actor.username}/feeds/#{feed.id}/edit", ACCEPT_JSON
        expect(response.status_code).to eq(404)
      end

      context "given a feed owned by another actor" do
        let_create!(:feed, named: other)

        it "returns 404" do
          get "/actors/#{actor.username}/feeds/#{other.id}/edit", ACCEPT_HTML
          expect(response.status_code).to eq(404)
        end

        it "returns 404" do
          get "/actors/#{actor.username}/feeds/#{other.id}/edit", ACCEPT_JSON
          expect(response.status_code).to eq(404)
        end
      end

      it "succeeds" do
        get "/actors/#{actor.username}/feeds/#{feed.id}/edit", ACCEPT_HTML
        expect(response.status_code).to eq(200)
      end

      it "succeeds" do
        get "/actors/#{actor.username}/feeds/#{feed.id}/edit", ACCEPT_JSON
        expect(response.status_code).to eq(200)
      end

      it "renders the form" do
        get "/actors/#{actor.username}/feeds/#{feed.id}/edit", ACCEPT_HTML
        body = XML.parse_html(response.body)
        expect(form_fields("name", "any", "all", "none")).to eq({"Robotics", "#cnc", "", ""})
      end

      it "renders the representation" do
        get "/actors/#{actor.username}/feeds/#{feed.id}/edit", ACCEPT_JSON
        body = JSON.parse(response.body)
        expect(json_fields("name", "any", "all", "none")).to eq({"Robotics", "#cnc", "", ""})
      end

      it "renders an empty preview" do
        get "/actors/#{actor.username}/feeds/#{feed.id}/edit", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//div[contains(@class,'feed-preview')]//text()").map(&.text).join).to contain("There is nothing here, yet")
      end

      it "renders an empty preview" do
        get "/actors/#{actor.username}/feeds/#{feed.id}/edit", ACCEPT_JSON
        expect(JSON.parse(response.body)["matches"].as_a).to be_empty
      end

      context "that is published and has contents" do
        let_create(:object, named: hit)

        before_each do
          feed.assign(draft: false).save
          put_in_feed(feed, hit)
        end

        it "renders the matches" do
          get "/actors/#{actor.username}/feeds/#{feed.id}/edit", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id")).to contain("object-#{hit.id}")
        end

        it "renders the matches" do
          get "/actors/#{actor.username}/feeds/#{feed.id}/edit", ACCEPT_JSON
          expect(JSON.parse(response.body)["matches"].as_a.map(&.as_i64)).to contain(hit.id)
        end
      end

      context "that is a draft and has matches" do
        let_create(:object, named: hit)

        before_each do
          feed.assign(draft: true).save
          put_in_feed(feed, hit)
        end

        it "renders the matches" do
          get "/actors/#{actor.username}/feeds/#{feed.id}/edit", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id")).to contain("object-#{hit.id}")
        end

        it "renders the matches" do
          get "/actors/#{actor.username}/feeds/#{feed.id}/edit", ACCEPT_JSON
          expect(JSON.parse(response.body)["matches"].as_a.map(&.as_i64)).to contain(hit.id)
        end
      end
    end
  end

  # the state transition diagram in feeds.cr documents the behavior of
  # this endpoint

  describe "POST /actors/:username/feeds/:id" do
    let_create!(:feed, owner: actor, name: "Robotics", params: JSON.parse(%({"hashtags":{"any":["cnc"]}})).as_h)

    it "returns 401 if not authorized" do
      post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, "name=Robotics&any=%23robotics"
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, %({"name":"Robotics","any":"#robotics"})
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "returns 404 for a different account" do
        post "/actors/#{register.actor.username}/feeds/#{feed.id}", FORM_HEADERS, "name=Robotics&any=%23robotics"
        expect(response.status_code).to eq(404)
      end

      it "returns 404 for a different account" do
        post "/actors/#{register.actor.username}/feeds/#{feed.id}", JSON_HEADERS, %({"name":"Robotics","any":"#robotics"})
        expect(response.status_code).to eq(404)
      end

      context "given a feed owned by another actor" do
        let_create!(:feed, named: other, name: "Other")

        it "returns 404" do
          post "/actors/#{actor.username}/feeds/#{other.id}", FORM_HEADERS, "name=Other&any=%23robotics"
          expect(response.status_code).to eq(404)
        end

        it "returns 404" do
          post "/actors/#{actor.username}/feeds/#{other.id}", JSON_HEADERS, %({"name":"Other","any":"#robotics"})
          expect(response.status_code).to eq(404)
        end
      end

      it "returns 413 if the body is too large" do
        post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, "name=Robotics&any=#{"x" * FeedsController::MAX_REQUEST_BYTES}"
        expect(response.status_code).to eq(413)
      end

      it "returns 413 if the body is too large" do
        post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, %({"name":"Robotics","any":"#{"x" * FeedsController::MAX_REQUEST_BYTES}"})
        expect(response.status_code).to eq(413)
      end

      def robotics_feed
        Feed.find(name: "Robotics")
      end

      context "when publishing a changed published feed" do
        it "deletes the original" do
          post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, "name=Robotics&any=%23robotics"
          expect(Feed.find?(feed.id)).to be_nil
        end

        it "deletes the original" do
          post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, %({"name":"Robotics","any":"#robotics"})
          expect(Feed.find?(feed.id)).to be_nil
        end

        it "leaves the total count unchanged" do
          expect { post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, "name=Robotics&any=%23robotics" }
            .not_to change { Feed.count }
        end

        it "leaves the total count unchanged" do
          expect { post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, %({"name":"Robotics","any":"#robotics"}) }
            .not_to change { Feed.count }
        end

        it "translates the criteria into params" do
          post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, "name=Robotics&any=%23robotics"
          expect(robotics_feed.params).to eq(JSON.parse(%({"hashtags":{"any":["robotics"]}})).as_h)
        end

        it "translates the criteria into params" do
          post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, %({"name":"Robotics","any":"#robotics"})
          expect(robotics_feed.params).to eq(JSON.parse(%({"hashtags":{"any":["robotics"]}})).as_h)
        end

        it "registers the feed's view" do
          post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, "name=Robotics&any=%23robotics"
          expect(Rules::View.registry.map(&.type)).to contain(robotics_feed.feed_type)
        end

        it "registers the feed's view" do
          post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, %({"name":"Robotics","any":"#robotics"})
          expect(Rules::View.registry.map(&.type)).to contain(robotics_feed.feed_type)
        end

        context "when the original is registered" do
          before_each { Rules::Feeds.register(feed) }

          pre_condition { expect(Rules::View.registry.map(&.type)).to contain(feed.feed_type) }

          it "unregisters the original feed's view" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, "name=Robotics&any=%23robotics"
            expect(Rules::View.registry.map(&.type)).not_to contain(feed.feed_type)
          end

          it "unregisters the original feed's view" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, %({"name":"Robotics","any":"#robotics"})
            expect(Rules::View.registry.map(&.type)).not_to contain(feed.feed_type)
          end
        end

        it "succeeds" do
          post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, "name=Robotics&any=%23robotics"
          expect(response.status_code).to eq(302)
        end

        it "succeeds" do
          post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, %({"name":"Robotics","any":"#robotics"})
          expect(response.status_code).to eq(302)
        end

        it "redirects to the index" do
          post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, "name=Robotics&any=%23robotics"
          expect(response.headers["Location"]).to eq("/actors/#{actor.username}/feeds")
        end

        it "returns the index" do
          post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, %({"name":"Robotics","any":"#robotics"})
          expect(response.headers["Location"]).to eq("/actors/#{actor.username}/feeds")
        end

        context "and the original has contents" do
          let_create!(:object, named: kept)
          let_create!(:hashtag, named: nil, subject: kept, name: "cnc")
          let_create!(:hashtag, named: nil, subject: kept, name: "robotics")
          let_create!(:feed_verdict, named: nil, feed: feed, object: kept, included: true)

          it "carries the retained post into the successor" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, "name=Robotics&any=%23robotics"
            expect(robotics_feed.contents.map(&.iri)).to contain(kept.iri)
          end

          it "carries the retained post into the successor" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, %({"name":"Robotics","any":"#robotics"})
            expect(robotics_feed.contents.map(&.iri)).to contain(kept.iri)
          end
        end

        context "given a blank name" do
          it "returns 422" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, "name=&any=%23robotics"
            expect(response.status_code).to eq(422)
          end

          it "returns 422" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, %({"name":"","any":"#robotics"})
            expect(response.status_code).to eq(422)
          end

          it "does not delete the original" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, "name=&any=%23robotics"
            expect(Feed.find?(feed.id)).not_to be_nil
          end

          it "does not delete the original" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, %({"name":"","any":"#robotics"})
            expect(Feed.find?(feed.id)).not_to be_nil
          end

          it "does not create a replacement" do
            expect { post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, "name=&any=%23robotics" }
              .not_to change { Feed.count }
          end

          it "does not create a replacement" do
            expect { post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, %({"name":"","any":"#robotics"}) }
              .not_to change { Feed.count }
          end
        end
      end

      context "when previewing a changed published feed" do
        let_create(:object, named: hit, content: "<p>robotics arm</p>")
        let_create(:create, named: hit_create, object: hit)

        before_each { put_in_inbox(actor, hit_create) }

        def preview_form
          "name=Robotics&any=robotics&preview=1"
        end

        def preview_json
          %({"name":"Robotics","any":"robotics","preview":"1"})
        end

        def copy
          Feed.where("name = ? AND id <> ?", "Robotics", feed.id).first
        end

        it "creates a copy" do
          expect { post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, preview_form }
            .to change { Feed.count }.by(1)
        end

        it "creates a copy" do
          expect { post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, preview_json }
            .to change { Feed.count }.by(1)
        end

        it "marks the copy as a draft" do
          post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, preview_form
          expect(copy.draft).to be_true
        end

        it "marks the copy as a draft" do
          post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, preview_json
          expect(copy.draft).to be_true
        end

        it "leaves the original untouched" do
          post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, preview_form
          expect(Feed.find(feed.id).draft).to be_false
        end

        it "leaves the original untouched" do
          post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, preview_json
          expect(Feed.find(feed.id).draft).to be_false
        end

        it "does not register the copy's view" do
          post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, preview_form
          expect(Rules::View.registry.map(&.type)).not_to contain(copy.feed_type)
        end

        it "does not register the copy's view" do
          post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, preview_json
          expect(Rules::View.registry.map(&.type)).not_to contain(copy.feed_type)
        end

        it "succeeds" do
          post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, preview_form
          expect(response.status_code).to eq(302)
        end

        it "succeeds" do
          post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, preview_json
          expect(response.status_code).to eq(302)
        end

        it "links the copy to the original" do
          post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, preview_form
          expect(copy.copy_of).to eq(feed.id)
        end

        it "links the copy to the original" do
          post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, preview_json
          expect(copy.copy_of).to eq(feed.id)
        end

        it "redirects to the copy's editor" do
          post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, preview_form
          expect(response.headers["Location"]).to eq("/actors/#{actor.username}/feeds/#{copy.id}/edit")
        end

        it "redirects to the copy's editor" do
          post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, preview_json
          expect(response.headers["Location"]).to eq("/actors/#{actor.username}/feeds/#{copy.id}/edit")
        end

        it "adds the matching post to the window" do
          post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, preview_form
          get "/actors/#{actor.username}/feeds/#{copy.id}/edit", ACCEPT_HTML
          expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id")).to contain("object-#{hit.id}")
        end

        it "adds the matching post to the window" do
          post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, preview_json
          get "/actors/#{actor.username}/feeds/#{copy.id}/edit", ACCEPT_JSON
          expect(JSON.parse(response.body)["matches"].as_a.map(&.as_i64)).to contain(hit.id)
        end

        context "given a blank name" do
          it "returns 422" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, "name=&any=robotics&preview=1"
            expect(response.status_code).to eq(422)
          end

          it "returns 422" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, %({"name":"","any":"robotics","preview":"1"})
            expect(response.status_code).to eq(422)
          end

          it "does not create a copy" do
            expect { post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, "name=&any=robotics&preview=1" }
              .not_to change { Feed.count }
          end

          it "does not create a copy" do
            expect { post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, %({"name":"","any":"robotics","preview":"1"}) }
              .not_to change { Feed.count }
          end
        end

        context "given an earlier draft copy" do
          let_create!(:feed, named: superseded, owner: actor, name: "Earlier", draft: true, copy_of: feed.id)

          it "discards the superseded copy" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, preview_form
            expect(Feed.find?(superseded.id)).to be_nil
          end

          it "discards the superseded copy" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, preview_json
            expect(Feed.find?(superseded.id)).to be_nil
          end

          context "of a different feed" do
            let_create!(:feed, named: other, owner: actor, name: "Other")

            before_each { superseded.assign(copy_of: other.id).save }

            it "does not discard the superseded copy" do
              post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, preview_form
              expect(Feed.find?(superseded.id)).not_to be_nil
            end

            it "does not discard the superseded copy" do
              post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, preview_json
              expect(Feed.find?(superseded.id)).not_to be_nil
            end
          end

          context "and a rejected preview" do
            it "does not discard the superseded copy" do
              post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, "name=&any=robotics&preview=1"
              expect(Feed.find?(superseded.id)).not_to be_nil
            end

            it "does not discard the superseded copy" do
              post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, %({"name":"","any":"robotics","preview":"1"})
              expect(Feed.find?(superseded.id)).not_to be_nil
            end
          end
        end
      end

      context "given a draft feed" do
        before_each { feed.assign(draft: true).save }

        context "when previewing a draft feed" do
          let_create(:object, named: hit)
          let_create!(:hashtag, subject: hit, name: "cnc")
          let_create(:create, named: hit_create, object: hit)

          before_each { put_in_inbox(actor, hit_create) }

          def preview_form
            "name=Robotics&any=%23cnc&preview=1"
          end

          def preview_json
            %({"name":"Robotics","any":"#cnc","preview":"1"})
          end

          it "keeps the feed a draft" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, preview_form
            expect(Feed.find(feed.id).draft).to be_true
          end

          it "keeps the feed a draft" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, preview_json
            expect(Feed.find(feed.id).draft).to be_true
          end

          it "does not register the draft's view" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, preview_form
            expect(Rules::View.registry.map(&.type)).not_to contain(feed.feed_type)
          end

          it "does not register the draft's view" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, preview_json
            expect(Rules::View.registry.map(&.type)).not_to contain(feed.feed_type)
          end

          it "succeeds" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, preview_form
            expect(response.status_code).to eq(302)
          end

          it "succeeds" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, preview_json
            expect(response.status_code).to eq(302)
          end

          it "redirects to the editor" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, preview_form
            expect(response.headers["Location"]).to eq("/actors/#{actor.username}/feeds/#{feed.id}/edit")
          end

          it "redirects to the editor" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, preview_json
            expect(response.headers["Location"]).to eq("/actors/#{actor.username}/feeds/#{feed.id}/edit")
          end

          it "adds the matching post to the window" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, preview_form
            get "/actors/#{actor.username}/feeds/#{feed.id}/edit", ACCEPT_HTML
            expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id")).to contain("object-#{hit.id}")
          end

          it "adds the matching post to the window" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, preview_json
            get "/actors/#{actor.username}/feeds/#{feed.id}/edit", ACCEPT_JSON
            expect(JSON.parse(response.body)["matches"].as_a.map(&.as_i64)).to contain(hit.id)
          end

          context "given a previewed window" do
            before_each { post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, preview_form }

            context "when the criteria are unchanged" do
              it "does not recompute the window" do
                expect { post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, preview_form }
                  .not_to change { Feed::Verdict.find?(feed_id: feed.id, object_iri: hit.iri).try(&.id) }
              end

              it "does not recompute the window" do
                expect { post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, preview_json }
                  .not_to change { Feed::Verdict.find?(feed_id: feed.id, object_iri: hit.iri).try(&.id) }
              end
            end

            context "when the criteria change" do
              it "recomputes the window under the new criteria" do
                expect { post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, "name=Robotics&any=%23resin&preview=1" }
                  .to change { Feed::Verdict.find?(feed_id: feed.id, object_iri: hit.iri).try(&.included) }.from(true).to(false)
              end

              it "recomputes the window under the new criteria" do
                expect { post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, %({"name":"Robotics","any":"#resin","preview":"1"}) }
                  .to change { Feed::Verdict.find?(feed_id: feed.id, object_iri: hit.iri).try(&.included) }.from(true).to(false)
              end
            end
          end
        end

        context "when publishing a draft feed" do
          def publish_form
            "name=Robotics&any=%23cnc"
          end

          def publish_json
            %({"name":"Robotics","any":"#cnc"})
          end

          it "publishes the draft" do
            expect { post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, publish_form }
              .to change { Feed.find(feed.id).draft }.from(true).to(false)
          end

          it "publishes the draft" do
            expect { post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, publish_json }
              .to change { Feed.find(feed.id).draft }.from(true).to(false)
          end

          it "registers the view" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, publish_form
            expect(Rules::View.registry.map(&.type)).to contain(feed.feed_type)
          end

          it "registers the view" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, publish_json
            expect(Rules::View.registry.map(&.type)).to contain(feed.feed_type)
          end

          it "succeeds" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, publish_form
            expect(response.status_code).to eq(302)
          end

          it "succeeds" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, publish_json
            expect(response.status_code).to eq(302)
          end

          it "redirects to the index" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, publish_form
            expect(response.headers["Location"]).to eq("/actors/#{actor.username}/feeds")
          end

          it "returns the index" do
            post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, publish_json
            expect(response.headers["Location"]).to eq("/actors/#{actor.username}/feeds")
          end

          context "given a blank name" do
            it "returns 422" do
              post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, "name=&any=%23cnc"
              expect(response.status_code).to eq(422)
            end

            it "returns 422" do
              post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, %({"name":"","any":"#cnc"})
              expect(response.status_code).to eq(422)
            end

            it "does not publish the draft" do
              post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, "name=&any=%23cnc"
              expect(Feed.find(feed.id).draft).to be_true
            end

            it "does not publish the draft" do
              post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, %({"name":"","any":"#cnc"})
              expect(Feed.find(feed.id).draft).to be_true
            end
          end

          context "given a previewed window" do
            let_create(:object, named: hit)
            let_create!(:feed_verdict, feed: feed, object: hit, included: true)

            before_each { put_in_feed(feed, hit) }

            pre_condition { expect(Feed::Verdict.count(feed_id: feed.id)).to eq(1) }

            it "adopts the previewed matches" do
              post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, publish_form
              get "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_HTML
              expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id")).to contain("object-#{hit.id}")
            end

            it "adopts the previewed matches" do
              post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, publish_json
              get "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_JSON
              expect(JSON.parse(response.body).dig("first", "orderedItems").as_a.map(&.as_s)).to contain(hit.iri)
            end

            it "does not recompute the verdicts" do
              expect { post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, publish_form }
                .not_to change { Feed::Verdict.count(feed_id: feed.id) }.from(1)
            end

            it "does not recompute the verdicts" do
              expect { post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, publish_json }
                .not_to change { Feed::Verdict.count(feed_id: feed.id) }.from(1)
            end

            context "but the criteria changed" do
              def publish_changed_form
                "name=Robotics&any=%23resin"
              end

              def publish_changed_json
                %({"name":"Robotics","any":"#resin"})
              end

              it "deletes the previewed verdicts" do
                expect { post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, publish_changed_form }
                  .to change { Feed::Verdict.count(feed_id: feed.id) }.from(1).to(0)
              end

              it "deletes the previewed verdicts" do
                expect { post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, publish_changed_json }
                  .to change { Feed::Verdict.count(feed_id: feed.id) }.from(1).to(0)
              end

              it "drops the stale match" do
                post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, publish_changed_form
                get "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_HTML
                expect(XML.parse_html(response.body).xpath_nodes("//*[contains(@class,'event')]/@id")).not_to contain("object-#{hit.id}")
              end

              it "drops the stale match" do
                post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, publish_changed_json
                get "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_JSON
                expect(response.body).not_to contain(hit.iri)
              end
            end
          end

          context "that is a copy of an original feed" do
            let_create!(:feed, named: original, owner: actor, name: "Original")

            before_each { feed.assign(original: original).save }

            it "deletes the original" do
              expect { post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, publish_form }
                .to change { Feed.find?(original.id) }.to(nil)
            end

            it "deletes the original" do
              expect { post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, publish_json }
                .to change { Feed.find?(original.id) }.to(nil)
            end

            it "publishes the copy" do
              post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, publish_form
              expect(Feed.find(feed.id).draft).to be_false
            end

            it "publishes the copy" do
              post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, publish_json
              expect(Feed.find(feed.id).draft).to be_false
            end

            context "when the original is registered" do
              before_each { Rules::Feeds.register(original) }

              pre_condition { expect(Rules::View.registry.map(&.type)).to contain(original.feed_type) }

              it "unregisters the original's view" do
                post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, publish_form
                expect(Rules::View.registry.map(&.type)).not_to contain(original.feed_type)
              end

              it "unregisters the original's view" do
                post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, publish_json
                expect(Rules::View.registry.map(&.type)).not_to contain(original.feed_type)
              end
            end

            context "and the original has contents" do
              let_create!(:object, named: kept, content: "<p>keyword</p>")
              let_create!(:hashtag, named: nil, subject: kept, name: "cnc")
              let_create!(:feed_verdict, named: nil, feed: original, object: kept, included: true)

              it "carries the retained post into the successor" do
                post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, publish_form
                expect(Feed.find(feed.id).contents.map(&.iri)).to contain(kept.iri)
              end

              it "carries the retained post into the successor" do
                post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, publish_json
                expect(Feed.find(feed.id).contents.map(&.iri)).to contain(kept.iri)
              end
            end

            context "that no longer exists" do
              before_each { original.destroy }

              it "publishes the copy" do
                post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, publish_form
                expect(Feed.find(feed.id).draft).to be_false
              end

              it "publishes the copy" do
                post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, publish_json
                expect(Feed.find(feed.id).draft).to be_false
              end
            end
          end

          context "that is a copy of a feed owned by another actor" do
            let_create!(:feed, named: foreign, name: "Foreign")

            before_each { feed.assign(copy_of: foreign.id).save }

            it "does not delete the other feed" do
              post "/actors/#{actor.username}/feeds/#{feed.id}", FORM_HEADERS, publish_form
              expect(Feed.find?(foreign.id)).not_to be_nil
            end

            it "does not delete the other feed" do
              post "/actors/#{actor.username}/feeds/#{feed.id}", JSON_HEADERS, publish_json
              expect(Feed.find?(foreign.id)).not_to be_nil
            end
          end
        end
      end
    end
  end

  describe "DELETE /actors/:username/feeds/:id" do
    let_create!(:feed, owner: actor)

    it "returns 401 if not authorized" do
      delete "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_HTML
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      delete "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_JSON
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "returns 404 for a different account" do
        delete "/actors/#{register.actor.username}/feeds/#{feed.id}", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 for a different account" do
        delete "/actors/#{register.actor.username}/feeds/#{feed.id}", ACCEPT_JSON
        expect(response.status_code).to eq(404)
      end

      it "deletes the feed" do
        expect { delete "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_HTML }
          .to change { Feed.count }.by(-1)
      end

      it "deletes the feed" do
        expect { delete "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_JSON }
          .to change { Feed.count }.by(-1)
      end

      it "succeeds" do
        delete "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_HTML
        expect(response.status_code).to eq(302)
      end

      it "succeeds" do
        delete "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_JSON
        expect(response.status_code).to eq(302)
      end

      it "redirects to the index" do
        delete "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_HTML
        expect(response.headers["Location"]).to eq("/actors/#{actor.username}/feeds")
      end

      it "returns the index" do
        delete "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_JSON
        expect(response.headers["Location"]).to eq("/actors/#{actor.username}/feeds")
      end

      context "given a materialized post and its verdict" do
        let_create(:object)
        let_create!(:feed_verdict, feed: feed, object: object)

        before_each { put_in_feed(feed, object) }

        def materialized_count(feed)
          Ktistec.database.query_one("SELECT COUNT(*) FROM relationships WHERE type = ?", feed.feed_type, as: Int64)
        end

        pre_condition do
          expect(Feed::Verdict.count(feed_id: feed.id)).to eq(1)
          expect(materialized_count(feed)).to eq(1)
        end

        it "removes the verdicts" do
          delete "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_HTML
          expect(Feed::Verdict.count(feed_id: feed.id)).to eq(0)
        end

        it "removes the verdicts" do
          delete "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_JSON
          expect(Feed::Verdict.count(feed_id: feed.id)).to eq(0)
        end

        it "removes the materialized rows" do
          delete "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_HTML
          expect(materialized_count(feed)).to eq(0)
        end

        it "removes the materialized rows" do
          delete "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_JSON
          expect(materialized_count(feed)).to eq(0)
        end
      end

      context "when the feed is registered" do
        before_each { Rules::Feeds.register(feed) }

        pre_condition { expect(Rules::View.registry.map(&.type)).to contain(feed.feed_type) }

        it "unregisters the view" do
          delete "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_HTML
          expect(Rules::View.registry.map(&.type)).not_to contain(feed.feed_type)
        end

        it "unregisters the view" do
          delete "/actors/#{actor.username}/feeds/#{feed.id}", ACCEPT_JSON
          expect(Rules::View.registry.map(&.type)).not_to contain(feed.feed_type)
        end
      end

      context "given a feed owned by another actor" do
        let_create!(:feed, named: other)

        it "returns 404" do
          delete "/actors/#{actor.username}/feeds/#{other.id}", ACCEPT_HTML
          expect(response.status_code).to eq(404)
        end

        it "returns 404" do
          delete "/actors/#{actor.username}/feeds/#{other.id}", ACCEPT_JSON
          expect(response.status_code).to eq(404)
        end

        it "does not delete the feed" do
          expect { delete "/actors/#{actor.username}/feeds/#{other.id}", ACCEPT_HTML }
            .not_to change { Feed.count }
        end

        it "does not delete the feed" do
          expect { delete "/actors/#{actor.username}/feeds/#{other.id}", ACCEPT_JSON }
            .not_to change { Feed.count }
        end
      end
    end
  end
end
