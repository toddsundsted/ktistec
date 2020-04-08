require "../spec_helper"

Spectator.describe Session do
  before_each { Balloon.database.exec "BEGIN TRANSACTION" }
  after_each { Balloon.database.exec "ROLLBACK" }

  def random_string
    ('a'..'z').to_a.shuffle.first(8).join
  end

  let(username) { random_string }
  let(password) { random_string }

  let(actor) { Actor.new(username, password).save }
  subject { described_class.new(actor).save }

  describe "#body=" do
    it "sets the body" do
      body = {"foo" => "bar"}
      expect{subject.body = body}.to change{subject.body_json}
    end
  end

  describe "#body" do
    it "gets the body" do
      body = subject.body = {"foo" => "bar"}
      expect(subject.body).to eq(body)
    end
  end

  describe "#actor=" do
    it "sets the actor" do
      actor = Actor.new(random_string, random_string).save
      expect{subject.actor = actor}.to change{subject.actor_id}
    end
  end

  describe "#actor" do
    it "gets the actor" do
      actor = subject.actor = Actor.new(random_string, random_string).save
      expect(subject.actor).to eq(actor)
    end
  end
end
