require "../../../src/rules/view/**" # ameba:disable Ktistec/NoRequireGlob

# the models are required explicitly so each class name below resolves to the
# real class -- an unrequired `Notification::Follow::Mention` resolves to the
# wrong class and `.to_s` drifts.

require "../../../src/models/relationship/content/notification/like"
require "../../../src/models/relationship/content/notification/dislike"
require "../../../src/models/relationship/content/notification/announce"
require "../../../src/models/relationship/content/notification/follow"
require "../../../src/models/relationship/content/notification/mention"
require "../../../src/models/relationship/content/notification/reply"
require "../../../src/models/relationship/content/notification/follow/hashtag"
require "../../../src/models/relationship/content/notification/follow/mention"
require "../../../src/models/relationship/content/notification/follow/thread"
require "../../../src/models/relationship/content/inbox"
require "../../../src/models/relationship/content/outbox"
require "../../../src/models/relationship/content/public_timeline"
require "../../../src/models/relationship/content/timeline/create"
require "../../../src/models/relationship/content/timeline/announce"
require "../../../src/models/relationship/content/follow/hashtag"
require "../../../src/models/relationship/content/follow/mention"
require "../../../src/models/relationship/content/follow/thread"
require "../../../src/models/activity_pub/activity/like"
require "../../../src/models/activity_pub/activity/dislike"
require "../../../src/models/activity_pub/activity/announce"
require "../../../src/models/activity_pub/activity/follow"
require "../../../src/models/activity_pub/activity/create"
require "../../../src/models/activity_pub/activity/update"
require "../../../src/models/tag/mention"
require "../../../src/models/tag/hashtag"

require "../../spec_helper/base"

Spectator.describe "Rules::View type-string constants" do
  it "Like" do
    expect(Rules::View::Like::TYPE).to eq(Relationship::Content::Notification::Like.to_s)
    expect(Rules::View::Like::LIKE).to eq(ActivityPub::Activity::Like.to_s)
    expect(Rules::View::Like::INBOX).to eq(Relationship::Content::Inbox.to_s)
    expect(Rules::View::Like::OUTBOX).to eq(Relationship::Content::Outbox.to_s)
  end

  it "Dislike" do
    expect(Rules::View::Dislike::TYPE).to eq(Relationship::Content::Notification::Dislike.to_s)
    expect(Rules::View::Dislike::DISLIKE).to eq(ActivityPub::Activity::Dislike.to_s)
    expect(Rules::View::Dislike::INBOX).to eq(Relationship::Content::Inbox.to_s)
    expect(Rules::View::Dislike::OUTBOX).to eq(Relationship::Content::Outbox.to_s)
  end

  it "Announce" do
    expect(Rules::View::Announce::TYPE).to eq(Relationship::Content::Notification::Announce.to_s)
    expect(Rules::View::Announce::ANNOUNCE).to eq(ActivityPub::Activity::Announce.to_s)
    expect(Rules::View::Announce::INBOX).to eq(Relationship::Content::Inbox.to_s)
    expect(Rules::View::Announce::OUTBOX).to eq(Relationship::Content::Outbox.to_s)
  end

  it "Follow" do
    expect(Rules::View::Follow::TYPE).to eq(Relationship::Content::Notification::Follow.to_s)
    expect(Rules::View::Follow::FOLLOW).to eq(ActivityPub::Activity::Follow.to_s)
    expect(Rules::View::Follow::INBOX).to eq(Relationship::Content::Inbox.to_s)
  end

  it "Mention" do
    expect(Rules::View::Mention::TYPE).to eq(Relationship::Content::Notification::Mention.to_s)
    expect(Rules::View::Mention::INBOX).to eq(Relationship::Content::Inbox.to_s)
    expect(Rules::View::Mention::CREATE).to eq(ActivityPub::Activity::Create.to_s)
    expect(Rules::View::Mention::ANNOUNCE).to eq(ActivityPub::Activity::Announce.to_s)
    expect(Rules::View::Mention::UPDATE).to eq(ActivityPub::Activity::Update.to_s)
    expect(Rules::View::Mention::MENTION).to eq(Tag::Mention.to_s)
  end

  it "Reply" do
    expect(Rules::View::Reply::TYPE).to eq(Relationship::Content::Notification::Reply.to_s)
    expect(Rules::View::Reply::INBOX).to eq(Relationship::Content::Inbox.to_s)
    expect(Rules::View::Reply::CREATE).to eq(ActivityPub::Activity::Create.to_s)
    expect(Rules::View::Reply::ANNOUNCE).to eq(ActivityPub::Activity::Announce.to_s)
    expect(Rules::View::Reply::UPDATE).to eq(ActivityPub::Activity::Update.to_s)
  end

  it "FollowHashtag" do
    expect(Rules::View::FollowHashtag::TYPE).to eq(Relationship::Content::Notification::Follow::Hashtag.to_s)
    expect(Rules::View::FollowHashtag::FOLLOW).to eq(Relationship::Content::Follow::Hashtag.to_s)
    expect(Rules::View::FollowHashtag::HASHTAG).to eq(Tag::Hashtag.to_s)
  end

  it "FollowMention" do
    expect(Rules::View::FollowMention::TYPE).to eq(Relationship::Content::Notification::Follow::Mention.to_s)
    expect(Rules::View::FollowMention::FOLLOW).to eq(Relationship::Content::Follow::Mention.to_s)
    expect(Rules::View::FollowMention::MENTION).to eq(Tag::Mention.to_s)
  end

  it "FollowThread" do
    expect(Rules::View::FollowThread::TYPE).to eq(Relationship::Content::Notification::Follow::Thread.to_s)
    expect(Rules::View::FollowThread::FOLLOW).to eq(Relationship::Content::Follow::Thread.to_s)
  end

  it "PublicTimeline" do
    expect(Rules::View::PublicTimeline::TYPE).to eq(Relationship::Content::PublicTimeline.to_s)
    expect(Rules::View::PublicTimeline::OUTBOX).to eq(Relationship::Content::Outbox.to_s)
    expect(Rules::View::PublicTimeline::CREATE).to eq(ActivityPub::Activity::Create.to_s)
    expect(Rules::View::PublicTimeline::ANNOUNCE).to eq(ActivityPub::Activity::Announce.to_s)
  end

  it "TimelineCreate" do
    expect(Rules::View::TimelineCreate::TYPE).to eq(Relationship::Content::Timeline::Create.to_s)
    expect(Rules::View::TimelineCreate::INBOX).to eq(Relationship::Content::Inbox.to_s)
    expect(Rules::View::TimelineCreate::OUTBOX).to eq(Relationship::Content::Outbox.to_s)
    expect(Rules::View::TimelineCreate::CREATE).to eq(ActivityPub::Activity::Create.to_s)
    expect(Rules::View::TimelineCreate::UPDATE).to eq(ActivityPub::Activity::Update.to_s)
    expect(Rules::View::TimelineCreate::MENTION).to eq(Tag::Mention.to_s)
  end

  it "TimelineAnnounce" do
    expect(Rules::View::TimelineAnnounce::TYPE).to eq(Relationship::Content::Timeline::Announce.to_s)
    expect(Rules::View::TimelineAnnounce::INBOX).to eq(Relationship::Content::Inbox.to_s)
    expect(Rules::View::TimelineAnnounce::OUTBOX).to eq(Relationship::Content::Outbox.to_s)
    expect(Rules::View::TimelineAnnounce::CREATE).to eq(ActivityPub::Activity::Create.to_s)
    expect(Rules::View::TimelineAnnounce::UPDATE).to eq(ActivityPub::Activity::Update.to_s)
    expect(Rules::View::TimelineAnnounce::ANNOUNCE).to eq(ActivityPub::Activity::Announce.to_s)
  end
end
