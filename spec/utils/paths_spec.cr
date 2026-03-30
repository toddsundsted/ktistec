require "../../src/utils/paths"

require "../spec_helper/base"
require "../spec_helper/controller"

Spectator.describe Utils::Paths do
  setup_spec

  describe ".path_id_from_iri" do
    it "returns the last path segment" do
      expect(Utils::Paths.path_id_from_iri("https://test.test/objects/abc123")).to eq("abc123")
    end

    it "returns the input" do
      expect(Utils::Paths.path_id_from_iri("abc123")).to eq("abc123")
    end
  end

  include Utils::Paths

  double :path_double do
    stub def id
      42
    end

    stub def iri
      "/xyz"
    end
  end

  describe "back_path" do
    let(env) do
      make_env("GET", "/filters/17").tap do |env|
        env.request.headers["Referer"] = "/back"
      end
    end

    it "gets the back path" do
      expect(back_path).to eq("/back")
    end
  end

  describe "home_path" do
    it "gets the home path" do
      expect(home_path).to eq("/")
    end
  end

  describe "sessions_path" do
    it "gets the sessions path" do
      expect(sessions_path).to eq("/sessions")
    end
  end

  describe "search_path" do
    it "gets the search path" do
      expect(search_path).to eq("/search")
    end
  end

  describe "settings_path" do
    it "gets the settings path" do
      expect(settings_path).to eq("/settings")
    end
  end

  describe "filters_path" do
    it "gets the filters path" do
      expect(filters_path).to eq("/filters")
    end
  end

  describe "filter_path" do
    let(env) do
      make_env("GET", "/filters/17").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given a term" do
      let(term) { double(:path_double) }

      it "gets the filter path" do
        expect(filter_path(term)).to eq("/filters/42")
      end
    end

    it "gets the filter path" do
      expect(filter_path).to eq("/filters/17")
    end
  end

  describe "system_path" do
    it "gets the system path" do
      expect(system_path).to eq("/system")
    end
  end

  describe "metrics_path" do
    it "gets the metrics path" do
      expect(metrics_path).to eq("/metrics")
    end
  end

  describe "tasks_path" do
    it "gets the tasks path" do
      expect(tasks_path).to eq("/tasks")
    end
  end

  describe "remote_activity_path" do
    let(env) do
      make_env("GET", "/remote/activities/17").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given an activity" do
      let(activity) { double(:path_double) }

      it "gets the remote activity path" do
        expect(remote_activity_path(activity)).to eq("/remote/activities/42")
      end
    end

    it "gets the remote activity path" do
      expect(remote_activity_path).to eq("/remote/activities/17")
    end
  end

  describe "activity_path" do
    let(env) do
      make_env("GET", "/activities/abc").tap do |env|
        env.params.url["id"] = "abc"
      end
    end

    context "given an activity" do
      let(activity) { double(:path_double) }

      it "gets the activity path" do
        expect(activity_path(activity)).to eq("/activities/xyz")
      end
    end

    it "gets the activity path" do
      expect(activity_path).to eq("/activities/abc")
    end
  end

  describe "anchor" do
    let(env) do
      make_env("GET", "/17").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given an object" do
      let(object) { double(:path_double) }

      it "gets the anchor" do
        expect(anchor(object)).to eq("object-42")
      end
    end

    it "gets the anchor" do
      expect(anchor).to eq("object-17")
    end
  end

  describe "objects_path" do
    it "gets the objects path" do
      expect(objects_path).to eq("/objects")
    end
  end

  describe "remote_object_path" do
    let(env) do
      make_env("GET", "/remote/objects/17").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given an object" do
      let(object) { double(:path_double) }

      it "gets the remote object path" do
        expect(remote_object_path(object)).to eq("/remote/objects/42")
      end
    end

    it "gets the remote object path" do
      expect(remote_object_path).to eq("/remote/objects/17")
    end
  end

  describe "object_path" do
    let(env) do
      make_env("GET", "/objects/abc").tap do |env|
        env.params.url["id"] = "abc"
      end
    end

    context "given an object" do
      let(object) { double(:path_double) }

      it "gets the object path" do
        expect(object_path(object)).to eq("/objects/xyz")
      end
    end

    it "gets the object path" do
      expect(object_path).to eq("/objects/abc")
    end
  end

  describe "remote_thread_path" do
    let(env) do
      make_env("GET", "/remote/objects/17/thread").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given an object" do
      let(object) { double(:path_double) }

      it "gets the remote thread path" do
        expect(remote_thread_path(object)).to eq("/remote/objects/42/thread#object-42")
      end
    end

    it "gets the remote thread path" do
      expect(remote_thread_path).to eq("/remote/objects/17/thread#object-17")
    end
  end

  describe "thread_path" do
    let(env) do
      make_env("GET", "/objects/abc/thread").tap do |env|
        env.params.url["id"] = "abc"
      end
    end

    context "given an object" do
      let(object) { double(:path_double) }

      it "gets the thread path" do
        expect(thread_path(object)).to eq("/objects/xyz/thread#object-42")
      end
    end

    it "gets the thread path" do
      expect(thread_path).to eq("/objects/abc/thread#object-abc")
    end
  end

  describe "edit_object_path" do
    let(env) do
      make_env("GET", "/objects/abc/edit").tap do |env|
        env.params.url["id"] = "abc"
      end
    end

    context "given an object" do
      let(object) { double(:path_double) }

      it "gets the edit object path" do
        expect(edit_object_path(object)).to eq("/objects/xyz/edit")
      end
    end

    it "gets the edit object path" do
      expect(edit_object_path).to eq("/objects/abc/edit")
    end
  end

  describe "reply_path" do
    let(env) do
      make_env("GET", "/remote/objects/17/reply").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given an object" do
      let(object) { double(:path_double) }

      it "gets the reply path" do
        expect(reply_path(object)).to eq("/remote/objects/42/reply")
      end
    end

    it "gets the reply path" do
      expect(reply_path).to eq("/remote/objects/17/reply")
    end
  end

  describe "approve_path" do
    let(env) do
      make_env("GET", "/remote/objects/17/approve").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given an object" do
      let(object) { double(:path_double) }

      it "gets the approve path" do
        expect(approve_path(object)).to eq("/remote/objects/42/approve")
      end
    end

    it "gets the approve path" do
      expect(approve_path).to eq("/remote/objects/17/approve")
    end
  end

  describe "unapprove_path" do
    let(env) do
      make_env("GET", "/remote/objects/17/unapprove").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given an object" do
      let(object) { double(:path_double) }

      it "gets the unapprove path" do
        expect(unapprove_path(object)).to eq("/remote/objects/42/unapprove")
      end
    end

    it "gets the unapprove path" do
      expect(unapprove_path).to eq("/remote/objects/17/unapprove")
    end
  end

  describe "block_object_path" do
    let(env) do
      make_env("GET", "/remote/objects/17/block").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given an object" do
      let(object) { double(:path_double) }

      it "gets the block object path" do
        expect(block_object_path(object)).to eq("/remote/objects/42/block")
      end
    end

    it "gets the block object path" do
      expect(block_object_path).to eq("/remote/objects/17/block")
    end
  end

  describe "unblock_object_path" do
    let(env) do
      make_env("GET", "/remote/objects/17/unblock").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given an object" do
      let(object) { double(:path_double) }

      it "gets the unblock object path" do
        expect(unblock_object_path(object)).to eq("/remote/objects/42/unblock")
      end
    end

    it "gets the unblock object path" do
      expect(unblock_object_path).to eq("/remote/objects/17/unblock")
    end
  end

  describe "object_remote_reply_path" do
    let(env) do
      make_env("GET", "/objects/abc/remote-reply").tap do |env|
        env.params.url["id"] = "abc"
      end
    end

    context "given an object" do
      let(object) { double(:path_double) }

      it "gets the object remote reply path" do
        expect(object_remote_reply_path(object)).to eq("/objects/xyz/remote-reply")
      end
    end

    it "gets the object remote reply path" do
      expect(object_remote_reply_path).to eq("/objects/abc/remote-reply")
    end
  end

  describe "object_remote_like_path" do
    let(env) do
      make_env("GET", "/objects/abc/remote-like").tap do |env|
        env.params.url["id"] = "abc"
      end
    end

    context "given an object" do
      let(object) { double(:path_double) }

      it "gets the object remote like path" do
        expect(object_remote_like_path(object)).to eq("/objects/xyz/remote-like")
      end
    end

    it "gets the object remote like path" do
      expect(object_remote_like_path).to eq("/objects/abc/remote-like")
    end
  end

  describe "object_remote_share_path" do
    let(env) do
      make_env("GET", "/objects/abc/remote-share").tap do |env|
        env.params.url["id"] = "abc"
      end
    end

    context "given an object" do
      let(object) { double(:path_double) }

      it "gets the object remote share path" do
        expect(object_remote_share_path(object)).to eq("/objects/xyz/remote-share")
      end
    end

    it "gets the object remote share path" do
      expect(object_remote_share_path).to eq("/objects/abc/remote-share")
    end
  end

  describe "create_translation_object_path" do
    let(env) do
      make_env("GET", "/remote/objects/17/translation/create").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given an object" do
      let(object) { double(:path_double) }

      it "gets the create translation object path" do
        expect(create_translation_object_path(object)).to eq("/remote/objects/42/translation/create")
      end
    end

    it "gets the create translation object path" do
      expect(create_translation_object_path).to eq("/remote/objects/17/translation/create")
    end
  end

  describe "clear_translation_object_path" do
    let(env) do
      make_env("GET", "/remote/objects/17/translation/clear").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given an object" do
      let(object) { double(:path_double) }

      it "gets the clear translation object path" do
        expect(clear_translation_object_path(object)).to eq("/remote/objects/42/translation/clear")
      end
    end

    it "gets the clear translation object path" do
      expect(clear_translation_object_path).to eq("/remote/objects/17/translation/clear")
    end
  end

  describe "remote_actor_path" do
    let(env) do
      make_env("GET", "/remote/actors/17").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given an actor" do
      let(actor) { double(:path_double) }

      it "gets the remote actor path" do
        expect(remote_actor_path(actor)).to eq("/remote/actors/42")
      end
    end

    it "gets the remote actor path" do
      expect(remote_actor_path).to eq("/remote/actors/17")
    end
  end

  describe "actor_path" do
    let(env) do
      make_env("GET", "/actors/abc").tap do |env|
        env.params.url["username"] = "abc"
      end
    end

    context "given an actor" do
      let(actor) { double(:path_double) }

      it "gets the actor path" do
        expect(actor_path(actor)).to eq("/actors/xyz")
      end
    end

    it "gets the actor path" do
      expect(actor_path).to eq("/actors/abc")
    end
  end

  describe "block_actor_path" do
    let(env) do
      make_env("GET", "/remote/actors/17/block").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given an actor" do
      let(actor) { double(:path_double) }

      it "gets the block actor path" do
        expect(block_actor_path(actor)).to eq("/remote/actors/42/block")
      end
    end

    it "gets the block actor path" do
      expect(block_actor_path).to eq("/remote/actors/17/block")
    end
  end

  describe "unblock_actor_path" do
    let(env) do
      make_env("GET", "/remote/actors/17/unblock").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given an actor" do
      let(actor) { double(:path_double) }

      it "gets the unblock actor path" do
        expect(unblock_actor_path(actor)).to eq("/remote/actors/42/unblock")
      end
    end

    it "gets the unblock actor path" do
      expect(unblock_actor_path).to eq("/remote/actors/17/unblock")
    end
  end

  describe "actor_relationships_path" do
    let(env) do
      make_env("GET", "/actors/abc/running").tap do |env|
        env.params.url["username"] = "abc"
        env.params.url["relationship"] = "running"
      end
    end

    context "given an actor and a relationship" do
      let(actor) { double(:path_double) }
      let(relationship) { "helping" }

      it "gets the actor relationships path" do
        expect(actor_relationships_path(actor, relationship)).to eq("/actors/xyz/helping")
      end
    end

    it "gets the actor relationships path" do
      expect(actor_relationships_path).to eq("/actors/abc/running")
    end
  end

  describe "outbox_path" do
    let(env) do
      make_env("GET", "/actors/abc/outbox").tap do |env|
        env.params.url["username"] = "abc"
      end
    end

    context "given an actor" do
      let(actor) { double(:path_double) }

      it "gets the outbox path" do
        expect(outbox_path(actor)).to eq("/actors/xyz/outbox")
      end
    end

    it "gets the outbox path" do
      expect(outbox_path).to eq("/actors/abc/outbox")
    end
  end

  describe "inbox_path" do
    let(env) do
      make_env("GET", "/actors/abc/inbox").tap do |env|
        env.params.url["username"] = "abc"
      end
    end

    context "given an actor" do
      let(actor) { double(:path_double) }

      it "gets the inbox path" do
        expect(inbox_path(actor)).to eq("/actors/xyz/inbox")
      end
    end

    it "gets the inbox path" do
      expect(inbox_path).to eq("/actors/abc/inbox")
    end
  end

  describe "actor_remote_follow_path" do
    let(env) do
      make_env("GET", "/actors/abc/remote-follow").tap do |env|
        env.params.url["username"] = "abc"
      end
    end

    context "given an actor" do
      let(actor) { double(:path_double) }

      it "gets the actor remote follow path" do
        expect(actor_remote_follow_path(actor)).to eq("/actors/xyz/remote-follow")
      end
    end

    it "gets the actor remote follow path" do
      expect(actor_remote_follow_path).to eq("/actors/abc/remote-follow")
    end
  end

  describe "hashtag_path" do
    let(env) do
      make_env("GET", "/tags/abc").tap do |env|
        env.params.url["hashtag"] = "abc"
      end
    end

    context "given a hashtag" do
      let(hashtag) { "xyz" }

      it "gets the hashtag path" do
        expect(hashtag_path(hashtag)).to eq("/tags/xyz")
      end
    end

    it "gets the hashtag path" do
      expect(hashtag_path).to eq("/tags/abc")
    end
  end

  describe "mention_path" do
    let(env) do
      make_env("GET", "/mentions/abc").tap do |env|
        env.params.url["mention"] = "abc"
      end
    end

    context "given a mention" do
      let(mention) { "xyz" }

      it "gets the mention path" do
        expect(mention_path(mention)).to eq("/mentions/xyz")
      end
    end

    it "gets the mentions path" do
      expect(mention_path).to eq("/mentions/abc")
    end
  end

  describe "remote_interaction_path" do
    it "gets the remote interaction path" do
      expect(remote_interaction_path).to eq("/remote-interaction")
    end
  end
end
