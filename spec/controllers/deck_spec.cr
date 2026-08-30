require "../../src/controllers/deck"
require "../../src/services/feed/backend/criteria"

require "../spec_helper/controller"
require "../spec_helper/factory"

Spectator.describe DeckController do
  setup_spec

  ACCEPT_HTML  = HTTP::Headers{"Accept" => "text/html"}
  FORM_HEADERS = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "text/html"}
  JSON_HEADERS = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded", "Accept" => "application/json"}

  let(account) { register }
  let(actor) { account.actor }

  macro post(index)
    let_create(:object, named: object{{index}})
    before_each { put_in_feed(robotics, object{{index}}, at: object{{index}}.created_at) }
  end

  macro pane(index)
    let_create!(:feed, named: pane{{index}}, owner: actor)
  end

  # Returns, for each rendered pane, whether each of its move controls
  # is disabled.
  #
  def disabled_moves(body)
    XML.parse_html(body).xpath_nodes("//section[contains(@class,'deck-pane')]").map do |pane|
      {left: move_disabled?(pane, "Move Left"), right: move_disabled?(pane, "Move Right")}
    end
  end

  # Returns whether the control labeled `label` is disabled. Raises if
  # there is no such control.
  #
  private def move_disabled?(pane, label)
    button = pane.xpath_nodes(".//button[normalize-space(.)=#{label.inspect}]").first
    !button["disabled"]?.nil?
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

        it "wraps the pane's contents in a frame" do
          get "/actors/#{actor.username}/deck", ACCEPT_HTML
          ids = XML.parse_html(response.body).xpath_nodes("//section[contains(@class,'deck-pane')]/turbo-frame/@id")
          expect(ids.map(&.text)).to eq(["feed-#{robotics.id}-pane"])
        end

        it "subscribes to the deck stream" do
          get "/actors/#{actor.username}/deck", ACCEPT_HTML
          src = XML.parse_html(response.body).xpath_nodes("//turbo-stream-source/@src").first?
          expect(src.try(&.text)).to eq("/stream/actor/deck")
        end

        it "renders an empty refresh slot inside the frame" do
          get "/actors/#{actor.username}/deck", ACCEPT_HTML
          slot = XML.parse_html(response.body).xpath_nodes("//turbo-frame[@id='feed-#{robotics.id}-pane']/*[@id='feed-#{robotics.id}-refresh']").first
          expect(slot.text).to be_empty
        end

        it "links the pane header to the feeds page" do
          get "/actors/#{actor.username}/deck", ACCEPT_HTML
          href = XML.parse_html(response.body).xpath_nodes("//section[contains(@class,'deck-pane')]//header//a/@href")
          expect(href.map(&.text)).to have("/actors/#{actor.username}/feeds")
        end

        it "links the pane header to the feed's edit form" do
          get "/actors/#{actor.username}/deck", ACCEPT_HTML
          href = XML.parse_html(response.body).xpath_nodes("//section[contains(@class,'deck-pane')]//header//a/@href")
          expect(href.map(&.text)).to have("/actors/#{actor.username}/feeds/#{robotics.slug}/edit")
        end

        it "points the move controls at the pane's position" do
          get "/actors/#{actor.username}/deck", ACCEPT_HTML
          actions = XML.parse_html(response.body).xpath_nodes("//section[contains(@class,'deck-pane')]//form[@class='pane-move']/@action")
          expect(actions.map(&.text)).to eq(["/actors/#{actor.username}/deck/panes/#{robotics.id}/position"] * 2)
        end

        it "disables both move controls" do
          get "/actors/#{actor.username}/deck", ACCEPT_HTML
          expect(disabled_moves(response.body)).to eq([{left: true, right: true}])
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

          it "disables the move controls that would do nothing" do
            get "/actors/#{actor.username}/deck", ACCEPT_HTML
            expect(disabled_moves(response.body)).to eq([{left: true, right: false}, {left: false, right: true}])
          end

          context "that shares a post" do
            let_create(:object, named: shared)

            before_each do
              put_in_feed(robotics, shared)
              put_in_feed(woodworking, shared)
            end

            it "scopes the posts to their panes" do
              get "/actors/#{actor.username}/deck", ACCEPT_HTML
              ids = XML.parse_html(response.body).xpath_nodes("//section[contains(@class,'deck-pane')]//turbo-frame[contains(@id,'-object-')]/@id")
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

        context "and more feeds than the deck shows" do
          {% for index in 1..12 %}
            pane({{index}})
          {% end %}

          pre_condition { expect(Feed.count).to be_gt(DeckController::MAX_PANES) }

          it "enables the last pane's move controls" do
            get "/actors/#{actor.username}/deck", ACCEPT_HTML
            expect(disabled_moves(response.body).last).to eq({left: false, right: false})
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

      context "given a Turbo-Frame header naming the pane" do
        let(path) { "/actors/#{actor.username}/deck/panes/#{robotics.id}" }

        let(headers) { HTTP::Headers{"Accept" => "text/html", "Turbo-Frame" => "feed-#{robotics.id}-pane"} }

        it "succeeds" do
          get path, headers
          expect(response.status_code).to eq(200)
        end

        it "renders the pane's frame" do
          get path, headers
          ids = XML.parse_html(response.body).xpath_nodes("//turbo-frame/@id").map(&.text)
          expect(ids.first).to eq("feed-#{robotics.id}-pane")
        end

        it "renders an empty refresh slot" do
          get path, headers
          slot = XML.parse_html(response.body).xpath_nodes("//*[@id='feed-#{robotics.id}-refresh']").first
          expect(slot.text).to be_empty
        end

        context "given posts in the feed" do
          let_create(:object, named: post)

          before_each { put_in_feed(robotics, post) }

          it "renders the posts" do
            get path, headers
            ids = XML.parse_html(response.body).xpath_nodes("//turbo-frame/@id").map(&.text)
            expect(ids).to have("feed-#{robotics.id}-object-#{post.id}")
          end
        end
      end

      context "given a Turbo-Frame header naming the sentinel" do
        let(path) { "/actors/#{actor.username}/deck/panes/#{robotics.id}" }

        let(headers) { HTTP::Headers{"Accept" => "text/html", "Turbo-Frame" => "feed-#{robotics.id}-sentinel"} }

        it "succeeds" do
          get path, headers
          expect(response.status_code).to eq(200)
        end

        it "replaces the sentinel" do
          get path, headers
          targets = XML.parse_html(response.body).xpath_nodes("//turbo-stream/@target").map(&.text)
          expect(targets).to eq(["feed-#{robotics.id}-sentinel"])
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

  describe "POST /actors/:username/deck/panes/:id/position" do
    let_create!(:feed, named: robotics, owner: actor, name: "Robotics")
    let_create!(:feed, named: woodworking, owner: actor, name: "Woodworking")

    # moves the pane with `id` to `position`
    def move(id, position, headers = FORM_HEADERS)
      post "/actors/#{actor.username}/deck/panes/#{id}/position", headers, "position=#{position}"
    end

    it "returns 401 if not authorized" do
      move(woodworking.id, 0)
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "returns 404 if the account does not exist" do
        post "/actors/missing/deck/panes/#{woodworking.id}/position", FORM_HEADERS, "position=0"
        expect(response.status_code).to eq(404)
      end

      it "returns 404 for a different account" do
        post "/actors/#{register.actor.username}/deck/panes/#{woodworking.id}/position", FORM_HEADERS, "position=0"
        expect(response.status_code).to eq(404)
      end

      it "returns 404 if the feed does not exist" do
        post "/actors/#{actor.username}/deck/panes/999999/position", FORM_HEADERS, "position=0"
        expect(response.status_code).to eq(404)
      end

      it "returns 400 if the position is missing" do
        post "/actors/#{actor.username}/deck/panes/#{woodworking.id}/position", FORM_HEADERS, ""
        expect(response.status_code).to eq(400)
      end

      context "given a feed owned by another account" do
        before_each { woodworking.assign(owner: register.actor).save }

        it "returns 404" do
          move(woodworking.id, 0)
          expect(response.status_code).to eq(404)
        end
      end

      it "returns 400 if the position is not a number" do
        move(woodworking.id, "first")
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if the position is before the first feed" do
        move(woodworking.id, -1)
        expect(response.status_code).to eq(400)
      end

      it "returns 400 if the position is past the last feed" do
        move(woodworking.id, 2)
        expect(response.status_code).to eq(400)
      end

      it "returns 413 if the body is too large" do
        move(woodworking.id, "9" * DeckController::MAX_REQUEST_BYTES)
        expect(response.status_code).to eq(413)
      end

      it "returns 302" do
        move(woodworking.id, 0, FORM_HEADERS)
        expect(response.status_code).to eq(302)
      end

      it "redirects to the deck" do
        move(woodworking.id, 0, FORM_HEADERS)
        expect(response.headers["Location"]?).to eq("/actors/#{actor.username}/deck")
      end

      it "returns 204" do
        move(woodworking.id, 0, JSON_HEADERS)
        expect(response.status_code).to eq(204)
      end

      it "moves the pane left" do
        expect { move(woodworking.id, 0) }.to change { account.reload!.feed_order }.from([] of String).to(["woodworking", "robotics"])
      end

      it "moves the pane right" do
        expect { move(robotics.id, 1) }.to change { account.reload!.feed_order }.from([] of String).to(["woodworking", "robotics"])
      end

      it "records the order when a pane is moved to where it already is" do
        expect { move(woodworking.id, 1) }.to change { account.reload!.feed_order }.from([] of String).to(["robotics", "woodworking"])
      end

      context "and the order has already been recorded" do
        before_each { move(woodworking.id, 0) }

        it "leaves it unchanged when the pane is moved to where it already is" do
          expect { move(woodworking.id, 0) }.not_to change { account.reload!.feed_order }.from(["woodworking", "robotics"])
        end
      end

      context "given a draft feed" do
        before_each { woodworking.assign(draft: true).save }

        it "returns 404" do
          move(woodworking.id, 0)
          expect(response.status_code).to eq(404)
        end
      end

      context "and more feeds than the deck shows" do
        # enough feeds to fill the deck, plus one it has no room for
        {% for index in 1..9 %}
          pane({{index}})
        {% end %}

        let_create!(:feed, named: last_shown, owner: actor)
        let_create!(:feed, named: first_hidden, owner: actor)

        def panes
          described_class.panes_for(account.reload!).map(&.id)
        end

        pre_condition { expect(panes.size).to eq(DeckController::MAX_PANES) }
        pre_condition { expect(panes).to contain(last_shown.id) }
        pre_condition { expect(panes).not_to contain(first_hidden.id) }

        it "moves the hidden feed onto the deck" do
          move(last_shown.id, DeckController::MAX_PANES)
          expect(panes).to contain(first_hidden.id)
        end

        it "drops the moved pane off the deck" do
          move(last_shown.id, DeckController::MAX_PANES)
          expect(panes).not_to contain(last_shown.id)
        end

        it "still shows MAX_PANES panes" do
          move(last_shown.id, DeckController::MAX_PANES)
          expect(panes.size).to eq(DeckController::MAX_PANES)
        end

        it "restores the deck" do
          original = panes
          move(last_shown.id, DeckController::MAX_PANES)
          move(first_hidden.id, DeckController::MAX_PANES)
          expect(panes).to eq(original)
        end
      end
    end
  end

  describe ".ordered_feeds_for" do
    context "given more feeds than MAX_PANES" do
      {% for index in 1..13 %}
        pane({{index}})
      {% end %}

      pre_condition { expect(Feed.count).to be_gt(DeckController::MAX_PANES) }

      it "returns every feed" do
        expect(described_class.ordered_feeds_for(account).size).to eq(Feed.count)
      end
    end
  end

  describe ".panes_for" do
    let_create!(:feed, named: robotics, owner: actor, name: "Robotics")

    it "returns the feed" do
      expect(described_class.panes_for(account).map(&.id)).to eq([robotics.id])
    end

    context "given a second feed" do
      let_create!(:feed, named: woodworking, owner: actor, name: "Woodworking")

      it "orders the feeds by id" do
        expect(described_class.panes_for(account).map(&.id)).to eq([robotics.id, woodworking.id])
      end

      context "and a feed order naming the second feed" do
        before_each { account.assign(feed_order: ["woodworking"]).save }

        it "returns the named feed first" do
          expect(described_class.panes_for(account).map(&.id)).to eq([woodworking.id, robotics.id])
        end
      end

      context "and a feed order with a slug that matches no feed" do
        before_each { account.assign(feed_order: ["gardening", "woodworking"]).save }

        it "ignores the unmatched slug" do
          expect(described_class.panes_for(account).map(&.id)).to eq([woodworking.id, robotics.id])
        end
      end
    end

    context "given a draft feed" do
      before_each { robotics.assign(draft: true).save }

      it "does not return the feed" do
        expect(described_class.panes_for(account)).to be_empty
      end
    end

    context "given a feed owned by another account" do
      before_each { robotics.assign(owner: register.actor).save }

      it "does not return the feed" do
        expect(described_class.panes_for(account)).to be_empty
      end
    end

    context "given more feeds than MAX_PANES" do
      {% for index in 1..12 %}
        pane({{index}})
      {% end %}

      pre_condition { expect(Feed.count).to be_gt(DeckController::MAX_PANES) }

      it "returns at most MAX_PANES" do
        expect(described_class.panes_for(account).size).to eq(DeckController::MAX_PANES)
      end

      it "drops the last feed" do
        expect(described_class.panes_for(account).map(&.id)).not_to contain(pane12.id)
      end

      context "and a feed order naming the last feed" do
        before_each { account.assign(feed_order: [pane12.slug.not_nil!]).save }

        it "keeps the last feed" do
          expect(described_class.panes_for(account).map(&.id)).to contain(pane12.id)
        end
      end
    end
  end
end
