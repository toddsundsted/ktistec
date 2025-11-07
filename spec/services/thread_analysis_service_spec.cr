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

  describe ".notable_branches" do
    let(branches) { ThreadAnalysisService.notable_branches(tuples) }

    it "sorts branches by size" do
      object_counts = branches.map(&.object_count)
      expect(object_counts).to eq(object_counts.sort.reverse)
    end

    it "includes only branches with >= 5 objects" do
      expect(branches.all? { |b| b.object_count >= 5 }).to be true
    end

    it "includes correct depth ranges" do
      branches.each do |branch|
        branch_tuples = branch.object_ids.compact_map { |id| tuples.find { |t| t[:id] == id } }
        depths = branch_tuples.map { |t| t[:depth] }
        expect(branch.depth_range).to eq({depths.min, depths.max})
      end
    end

    it "includes correct time spans" do
      branches.each do |branch|
        branch_tuples = branch.object_ids.compact_map { |id| tuples.find { |t| t[:id] == id } }
        times = branch_tuples.compact_map { |t| t[:published] }.sort
        expected_range = times.size >= 2 ? {times.first, times.last} : {times.first?, times.first?}
        expect(branch.time_range).to eq(expected_range)
      end
    end

    it "includes correct author counts" do
      branches.each do |branch|
        branch_tuples = branch.object_ids.compact_map { |id| tuples.find { |t| t[:id] == id } }
        author_count = branch_tuples.compact_map { |t| t[:attributed_to_iri] }.uniq
        expect(branch.author_count).to eq(author_count.size)
      end
    end

    it "includes all objects within max_depth" do
      # test assumes max_depth=2
      branches.each do |branch|
        root_tuple = tuples.find! { |t| t[:id] == branch.root_id }
        level_0 = [root_tuple]
        level_1 = tuples.select { |t| t[:in_reply_to_iri] == root_tuple[:iri] }
        level_1_iris = level_1.map { |t| t[:iri] }
        level_2 = tuples.select { |t| level_1_iris.includes?(t[:in_reply_to_iri]) }
        expected_ids = (level_0 + level_1 + level_2).map { |t| t[:id] }.to_set
        expect(branch.object_ids.to_set).to eq(expected_ids)
      end
    end

    it "returns at most 10 branches" do
      expect(branches.size).to be <= 10
    end

    it "respects custom threshold" do
      custom_branches = ThreadAnalysisService.notable_branches(tuples, threshold: 10)
      expect(custom_branches.all? { |b| b.object_count >= 10 }).to be true
    end

    it "respects custom limit" do
      custom_branches = ThreadAnalysisService.notable_branches(tuples, limit: 3)
      expect(custom_branches.size).to be <= 3
    end
  end

  context "edge cases" do
    it "handles single object" do
      tuple = [{
        id: 1_i64,
        iri: "https://test/1",
        in_reply_to_iri: nil,
        attributed_to_iri: "https://test/actor",
        published: Time.utc,
        depth: 0
      }]
      result = ThreadAnalysisService.notable_branches(tuple)
      expect(result).to be_empty
    end
  end
end
