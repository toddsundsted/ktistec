require "../spec_helper/base"
require "../../src/services/thread_analysis_service"

require "../fixtures/thread_analysis_service_data"

Spectator.describe ThreadAnalysisService do
  setup_spec

  before_each do
    init_thread_analysis_service_fixtures
  end

  let(root) { ActivityPub::Object.where("in_reply_to_iri IS NULL AND thread IS NOT NULL").first }
  let(tuples) { root.thread_query(projection: ActivityPub::Object::PROJECTION_METADATA) }

  describe ".key_participants" do
    let(participants) { ThreadAnalysisService.key_participants(tuples) }

    it "identifies OP as first participant" do
      expect(participants.first.actor_iri).to eq(root.attributed_to_iri)
    end

    it "sorts remaining participants by object count" do
      remaining = participants[1..-1]
      object_counts = remaining.map(&.object_count)
      expect(object_counts).to eq(object_counts.sort.reverse)
    end

    it "includes correct object counts" do
      participants.each do |participant|
        actual_count = tuples.count { |t| t[:attributed_to_iri] == participant.actor_iri }
        expect(participant.object_count).to eq(actual_count)
      end
    end

    it "includes correct depth ranges" do
      participants.each do |participant|
        depths = tuples
          .select { |t| t[:attributed_to_iri] == participant.actor_iri }
          .map { |t| t[:depth] }
        expect(participant.depth_range).to eq({depths.min, depths.max})
      end
    end

    it "includes correct time spans" do
      participants.each do |participant|
        participant_objects = tuples
          .select { |t| t[:attributed_to_iri] == participant.actor_iri }
          .compact_map { |t| t[:published] }
        expect(participant.time_range).to eq({participant_objects.min, participant_objects.max})
      end
    end

    it "includes all objects for each participant" do
      participants.each do |participant|
        expected_ids = tuples
          .select { |t| t[:attributed_to_iri] == participant.actor_iri }
          .map { |t| t[:id] }
          .sort
        expect(participant.object_ids.sort).to eq(expected_ids)
      end
    end

    it "returns limited participants plus OP" do
      participants = ThreadAnalysisService.key_participants(tuples, limit: 3)
      expect(participants.size).to eq(4)
      expect(participants.first.actor_iri).to eq(root.attributed_to_iri) # OP
    end

    it "the default limit is 5 plus OP" do
      participants = ThreadAnalysisService.key_participants(tuples)
      expect(participants.size).to eq(6)
    end
  end
end
