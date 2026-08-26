require "../../src/controllers/deck"
require "../../src/services/feed/backend/criteria"

require "../spec_helper/controller"
require "../spec_helper/factory"

Spectator.describe DeckController do
  setup_spec

  ACCEPT_HTML = HTTP::Headers{"Accept" => "text/html"}

  let(actor) { register.actor }

  macro post(index)
    let_create(:object, named: object{{index}})
    before_each { put_in_feed(robotics, object{{index}}, at: object{{index}}.created_at) }
  end

  describe "GET /actors/:username/deck" do
    it "returns 401 if not authorized" do
      get "/actors/#{actor.username}/deck", ACCEPT_HTML
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "returns 404 if the account does not exist" do
        get "/actors/missing/deck", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "returns 404 for a different account" do
        get "/actors/#{register.actor.username}/deck", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      it "succeeds" do
        get "/actors/#{actor.username}/deck", ACCEPT_HTML
        expect(response.status_code).to eq(200)
      end

      it "renders the empty page" do
        get "/actors/#{actor.username}/deck", ACCEPT_HTML
        expect(response.body).to contain("don't have any feeds yet")
      end

      it "links to the new feed form" do
        get "/actors/#{actor.username}/deck", ACCEPT_HTML
        href = XML.parse_html(response.body).xpath_nodes("//a[contains(@class,'button')]/@href").first?
        expect(href.try(&.text)).to eq("/actors/#{actor.username}/feeds/new")
      end

      context "given a feed" do
        let_create!(:feed, named: robotics, owner: actor, name: "Robotics")

        it "does not render the empty page" do
          get "/actors/#{actor.username}/deck", ACCEPT_HTML
          expect(response.body).not_to contain("don't have any feeds yet")
        end

        it "renders a pane for the feed" do
          get "/actors/#{actor.username}/deck", ACCEPT_HTML
          names = XML.parse_html(response.body).xpath_nodes("//section[contains(@class,'deck-pane')]//h2/text()")
          expect(names.map(&.text)).to have("Robotics")
        end

        it "links the pane header to the feed's edit form" do
          get "/actors/#{actor.username}/deck", ACCEPT_HTML
          href = XML.parse_html(response.body).xpath_nodes("//section[contains(@class,'deck-pane')]//header//a/@href")
          expect(href.map(&.text)).to have("/actors/#{actor.username}/feeds/#{robotics.id}/edit")
        end

        it "renders the pane as empty" do
          get "/actors/#{actor.username}/deck", ACCEPT_HTML
          expect(response.body).to contain("Nothing here yet")
        end

        context "given posts in the feed" do
          let_create(:object, named: earlier)
          let_create(:object, named: later)

          before_each do
            put_in_feed(robotics, earlier, at: Time.utc(2026, 1, 1))
            put_in_feed(robotics, later, at: Time.utc(2026, 1, 2))
          end

          it "does not render the pane as empty" do
            get "/actors/#{actor.username}/deck", ACCEPT_HTML
            expect(response.body).not_to contain("Nothing here yet")
          end

          it "renders the posts in the pane" do
            get "/actors/#{actor.username}/deck", ACCEPT_HTML
            ids = XML.parse_html(response.body).xpath_nodes("//section[contains(@class,'deck-pane')]//turbo-frame/@id")
            expect(ids.map(&.text)).to have("feed-#{robotics.id}-object-#{later.id}", "feed-#{robotics.id}-object-#{earlier.id}")
          end
        end

        context "given more posts than the endpoint returns" do
          # a full response below it + one more
          {% for index in 1..21 %}
            post({{index}})
          {% end %}

          it "renders a sentinel carrying the first cursor" do
            get "/actors/#{actor.username}/deck", ACCEPT_HTML
            sentinel = XML.parse_html(response.body).xpath_nodes("//turbo-frame[contains(@class,'sentinel')]").first
            expect({sentinel["id"], sentinel["src"]}).to eq({
              "feed-#{robotics.id}-sentinel",
              "/actors/#{actor.username}/deck/panes/#{robotics.id}?max_id=#{object2.id}",
            })
          end
        end

        context "and another feed" do
          let_create!(:feed, named: woodworking, owner: actor, name: "Woodworking")

          it "orders the panes by feed id" do
            get "/actors/#{actor.username}/deck", ACCEPT_HTML
            names = XML.parse_html(response.body).xpath_nodes("//section[contains(@class,'deck-pane')]//h2/text()")
            expect(names.map(&.text)).to eq(["Robotics", "Woodworking"])
          end

          context "that shares a post" do
            let_create(:object, named: shared)

            before_each do
              put_in_feed(robotics, shared)
              put_in_feed(woodworking, shared)
            end

            it "scopes the posts to their panes" do
              get "/actors/#{actor.username}/deck", ACCEPT_HTML
              ids = XML.parse_html(response.body).xpath_nodes("//section[contains(@class,'deck-pane')]//turbo-frame/@id")
              expect(ids.map(&.text)).to eq(["feed-#{robotics.id}-object-#{shared.id}", "feed-#{woodworking.id}-object-#{shared.id}"])
            end

            it "renders no duplicate ids" do
              get "/actors/#{actor.username}/deck", ACCEPT_HTML
              ids = XML.parse_html(response.body).xpath_nodes("//*/@id").map(&.text)
              expect(ids.sort).to eq(ids.uniq.sort!)
            end

            context "that quotes a post" do
              let_build(:object, named: quoted)

              before_each { shared.assign(quote: quoted).save }

              it "scopes the quote to its pane" do
                get "/actors/#{actor.username}/deck", ACCEPT_HTML
                ids = XML.parse_html(response.body).xpath_nodes("//turbo-frame/@id")
                expect(ids.map(&.text)).to have("feed-#{robotics.id}-quote-#{shared.id}", "feed-#{woodworking.id}-quote-#{shared.id}")
              end

              it "renders no duplicate ids" do
                get "/actors/#{actor.username}/deck", ACCEPT_HTML
                ids = XML.parse_html(response.body).xpath_nodes("//*/@id").map(&.text)
                expect(ids.sort).to eq(ids.uniq.sort!)
              end
            end
          end
        end

        context "that is a draft" do
          before_each { robotics.assign(draft: true).save }

          it "renders the empty page" do
            get "/actors/#{actor.username}/deck", ACCEPT_HTML
            expect(response.body).to contain("don't have any feeds yet")
          end
        end

        context "that belongs to another account" do
          before_each { robotics.assign(owner: register.actor).save }

          it "renders the empty page" do
            get "/actors/#{actor.username}/deck", ACCEPT_HTML
            expect(response.body).to contain("don't have any feeds yet")
          end
        end
      end
    end
  end

  describe "GET /actors/:username/deck/panes/:id" do
    let_create!(:feed, named: robotics, owner: actor, name: "Robotics")

    it "returns 401 if not authorized" do
      get "/actors/#{actor.username}/deck/panes/#{robotics.id}", ACCEPT_HTML
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "returns 404 if the feed does not exist" do
        get "/actors/#{actor.username}/deck/panes/999999", ACCEPT_HTML
        expect(response.status_code).to eq(404)
      end

      context "given a feed owned by another account" do
        let_create(:feed, named: theirs, owner: register.actor)

        it "returns 404" do
          get "/actors/#{actor.username}/deck/panes/#{theirs.id}", ACCEPT_HTML
          expect(response.status_code).to eq(404)
        end
      end

      context "given a draft feed" do
        before_each { robotics.assign(draft: true).save }

        it "returns 404" do
          get "/actors/#{actor.username}/deck/panes/#{robotics.id}", ACCEPT_HTML
          expect(response.status_code).to eq(404)
        end
      end

      context "given more posts than the endpoint returns" do
        # 22 = the post the cursor points at + a full response below it + one more
        {% for index in 1..22 %}
          post({{index}})
        {% end %}

        context "given a cursor" do
          let(cursor) { object22.id }

          let(path) { "/actors/#{actor.username}/deck/panes/#{robotics.id}?max_id=#{cursor}" }

          it "succeeds" do
            get path, ACCEPT_HTML
            expect(response.status_code).to eq(200)
          end

          it "sets the content type" do
            get path, ACCEPT_HTML
            expect(response.headers["Content-Type"]).to eq("text/vnd.turbo-stream.html")
          end

          it "renders a turbo stream" do
            get path, ACCEPT_HTML
            stream = XML.parse_html(response.body).xpath_nodes("//turbo-stream").first
            expect({stream["action"], stream["target"]}).to eq({"replace", "feed-#{robotics.id}-sentinel"})
          end

          it "does not return the current post" do
            get path, ACCEPT_HTML
            ids = XML.parse_html(response.body).xpath_nodes("//turbo-frame[contains(@id,'-object-')]/@id").map(&.text)
            expect(ids).not_to have("feed-#{robotics.id}-object-#{object22.id}")
          end

          it "returns posts newest to oldest" do
            get path, ACCEPT_HTML
            ids = XML.parse_html(response.body).xpath_nodes("//turbo-frame[contains(@id,'-object-')]/@id").map(&.text)
            expect(ids.first).to eq("feed-#{robotics.id}-object-#{object21.id}")
            expect(ids.last).to eq("feed-#{robotics.id}-object-#{object2.id}")
          end

          it "returns at most POSTS_PER_PANE" do
            get path, ACCEPT_HTML
            ids = XML.parse_html(response.body).xpath_nodes("//turbo-frame[contains(@id,'-object-')]/@id").map(&.text)
            expect(ids.size).to be_le(DeckController::POSTS_PER_PANE)
          end

          it "scopes the posts to the pane" do
            get path, ACCEPT_HTML
            ids = XML.parse_html(response.body).xpath_nodes("//turbo-frame[contains(@id,'-object-')]/@id").map(&.text)
            expect(ids.map(&.split("-object-").first).uniq!).to eq(["feed-#{robotics.id}"])
          end

          it "renders a sentinel carrying the next cursor" do
            get path, ACCEPT_HTML
            sentinel = XML.parse_html(response.body).xpath_nodes("//turbo-frame[contains(@class,'sentinel')]").first
            expect({sentinel["id"], sentinel["src"]}).to eq({
              "feed-#{robotics.id}-sentinel",
              "/actors/#{actor.username}/deck/panes/#{robotics.id}?max_id=#{object2.id}",
            })
          end

          context "and no posts remaining after those returned" do
            let(cursor) { object2.id }

            it "does not render a sentinel" do
              get path, ACCEPT_HTML
              sentinel = XML.parse_html(response.body).xpath_nodes("//turbo-frame[contains(@class,'sentinel')]").first?
              expect(sentinel).to be_nil
            end
          end

          context "that names a deleted post" do
            before_each { object22.delete! }

            it "returns no posts" do
              get path, ACCEPT_HTML
              ids = XML.parse_html(response.body).xpath_nodes("//turbo-frame[contains(@id,'-object-')]/@id").map(&.text)
              expect(ids).to be_empty
            end
          end
        end
      end
    end
  end
end
