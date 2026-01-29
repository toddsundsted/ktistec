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
      expect(object_counts).to eq(object_counts.sort.reverse!)
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
          .sort!
        expect(participant.object_ids.sort).to eq(expected_ids)
      end
    end

    it "returns limited participants (including OP)" do
      participants = ThreadAnalysisService.key_participants(tuples, limit: 4)
      expect(participants.size).to eq(4)
      expect(participants.first.actor_iri).to eq(root.attributed_to_iri) # OP
    end

    it "the default limit is 18 (including OP)" do
      participants = ThreadAnalysisService.key_participants(tuples)
      expect(participants.size).to eq(18)
    end

    context "when a participant has only draft posts" do
      let(tuples) do
        [
          {id: 1_i64, iri: "https://t/1", in_reply_to_iri: nil, attributed_to_iri: "https://t/op", published: base_time, depth: 0},
          {id: 2_i64, iri: "https://t/2", in_reply_to_iri: "https://t/1", attributed_to_iri: "https://t/nodates", published: nil, depth: 1},
        ]
      end

      it "excludes that participant" do
        expect(participants.map(&.actor_iri)).to contain_exactly("https://t/op")
      end
    end
  end

  let(base_time) { Time.utc(2025, 1, 1, 10, 0) }

  def make_thread(offsets : Array(Time::Span))
    offsets.map_with_index do |offset, idx|
      {
        id:                (idx + 1).to_i64,
        iri:               "https://test/#{idx + 1}",
        in_reply_to_iri:   idx == 0 ? nil : "https://test/1",
        attributed_to_iri: "https://test/actor#{idx + 1}",
        published:         base_time + offset,
        depth:             idx == 0 ? 0 : 1,
      }
    end
  end

  describe ".notable_branches" do
    let(branches) { ThreadAnalysisService.notable_branches(tuples) }

    it "sorts branches by size" do
      branch_scores = branches.map(&.score)
      expect(branch_scores).to eq(branch_scores.sort.reverse!)
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
        times = branch_tuples.compact_map { |t| t[:published] }.sort!
        expected_range = times.size >= 2 ? {times.first, times.last} : {times.first?, times.first?}
        expect(branch.time_range).to eq(expected_range)
      end
    end

    it "includes correct author counts" do
      branches.each do |branch|
        branch_tuples = branch.object_ids.compact_map { |id| tuples.find { |t| t[:id] == id } }
        author_count = branch_tuples.compact_map { |t| t[:attributed_to_iri] }.uniq!
        expect(branch.author_count).to eq(author_count.size)
      end
    end

    it "includes all objects" do
      branches.each do |branch|
        root_tuple = tuples.find! { |t| t[:id] == branch.root_id }
        expected_ids = ActivityPub::Object.find(root_tuple[:id]).descendants.map(&.id.not_nil!)
        expect(branch.object_ids.sort).to eq(expected_ids.sort)
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

    context "edge cases" do
      it "handles single object" do
        tuples = make_thread([0.minutes])
        expect(ThreadAnalysisService.notable_branches(tuples)).to be_empty
      end
    end
  end

  describe ".timeline_histogram" do
    let(histogram) { ThreadAnalysisService.timeline_histogram(tuples).not_nil! }

    it "sum of buckets matches total objects" do
      sum_of_buckets = histogram.buckets.sum(&.object_count)
      expect(sum_of_buckets).to eq(histogram.total_objects)
    end

    it "last bucket cumulative count matches total objects" do
      last_bucket = histogram.buckets.last
      expect(last_bucket.cumulative_count).to eq(histogram.total_objects)
    end

    it "returns histogram with correct bucket size" do
      duration = histogram.time_range[1] - histogram.time_range[0]
      expect(duration.total_hours).to be_between(24, 72)  # hours
      expect(histogram.bucket_size_minutes).to eq(6 * 60) # minutes
    end

    it "computes unique author counts per bucket" do
      histogram.buckets.each do |bucket|
        expect(bucket.author_count).to be_between(0, bucket.object_count)
      end
    end

    it "objects are placed in only one bucket" do
      all_ids = histogram.buckets.flat_map(&.object_ids)
      expect(all_ids.uniq.size).to eq(all_ids.size)
    end

    context "outlier elimination" do
      it "detects outliers when 6-hour minimum exceeds 3x median" do
        # fast thread: 1-min gaps, then 10-hour gap
        # median = 1 min, 3x median = 3 min, threshold = max(3 min, 6h) = 6h
        tuples = make_thread([0.seconds, 1.minute, 2.minutes, 10.hours])
        result = ThreadAnalysisService.timeline_histogram(tuples).not_nil!
        expect(result.total_objects).to eq(3)
        expect(result.outliers_excluded).to eq(1)
      end

      it "does not exclude gaps below 6-hour minimum" do
        # fast thread: 1-min gaps, with 4-hour gap
        # median = 1 min, threshold = 6h, gap of 4h < threshold
        tuples = make_thread([0.seconds, 1.minute, 2.minutes, 4.hours])
        result = ThreadAnalysisService.timeline_histogram(tuples).not_nil!
        expect(result.total_objects).to eq(4)
        expect(result.outliers_excluded).to eq(0)
      end

      it "detects outliers when 3x median exceeds 6-hour minimum" do
        # slow thread: 3-hour gaps, then 10-hour gap from last post
        # median = 3h, 3x median = 9h, threshold = max(9h, 6h) = 9h
        tuples = make_thread([0.hours, 3.hours, 6.hours, 16.hours])
        result = ThreadAnalysisService.timeline_histogram(tuples).not_nil!
        expect(result.total_objects).to eq(3)
        expect(result.outliers_excluded).to eq(1)
      end

      it "does not exclude gaps below 3x median" do
        # slow thread: 3-hour gaps consistently
        # median = 3h, threshold = 9h, all gaps are 3h
        tuples = make_thread([0.hours, 3.hours, 6.hours, 9.hours])
        result = ThreadAnalysisService.timeline_histogram(tuples).not_nil!
        expect(result.total_objects).to eq(4)
        expect(result.outliers_excluded).to eq(0)
      end
    end

    context "granularity selection" do
      it "uses 5-minute buckets for short threads" do
        # thread spanning 30 minutes (< 1 hour)
        tuples = make_thread([0.seconds, 30.minutes])
        result = ThreadAnalysisService.timeline_histogram(tuples).not_nil!
        expect(result.bucket_size_minutes).to eq(5)
      end

      it "uses hourly buckets for medium threads" do
        # thread spanning 6 hours (3-12 hour range)
        tuples = make_thread([0.seconds, 6.hours])
        result = ThreadAnalysisService.timeline_histogram(tuples).not_nil!
        expect(result.bucket_size_minutes).to eq(60)
      end

      it "uses daily buckets for week-long threads" do
        # thread spanning 10 days (1-4 week range)
        tuples = make_thread([0.seconds, 10.days])
        result = ThreadAnalysisService.timeline_histogram(tuples).not_nil!
        expect(result.bucket_size_minutes).to eq(1440)
      end

      it "uses weekly buckets for month-long threads" do
        # thread spanning 35 days (> 4 weeks)
        tuples = make_thread([0.seconds, 35.days])
        result = ThreadAnalysisService.timeline_histogram(tuples).not_nil!
        expect(result.bucket_size_minutes).to eq(10080)
      end
    end

    context "edge cases" do
      it "handles single object" do
        tuples = make_thread([0.minutes])
        expect(ThreadAnalysisService.timeline_histogram(tuples)).to be_nil
      end

      it "omits empty buckets in sparse threads" do
        # sparse thread: posts at 0h, 2h, and 2.5h
        # with 15-min buckets (1-3 hour range), posts land in buckets 0, 8, and 10
        result = ThreadAnalysisService.timeline_histogram(make_thread([0.hours, 2.hours, (2.5).hours])).not_nil!

        expect(result.bucket_size_minutes).to eq(15)
        expect(result.buckets.size).to eq(3)

        expect(result.buckets[0].time_range[0]).to be_within(1.millisecond).of(base_time)
        expect(result.buckets[0].time_range[1]).to be_within(1.millisecond).of(base_time + 15.minutes)

        expect(result.buckets[1].time_range[0]).to be_within(1.millisecond).of(base_time + 2.hours)
        expect(result.buckets[1].time_range[1]).to be_within(1.millisecond).of(base_time + 2.hours + 15.minutes)

        expect(result.buckets[2].time_range[0]).to be_within(1.millisecond).of(base_time + 2.hours + 30.minutes)
        expect(result.buckets[2].time_range[1]).to be_within(1.millisecond).of(base_time + 2.hours + 45.minutes)

        expect(result.buckets[0].object_count).to eq(1)
        expect(result.buckets[1].object_count).to eq(1)
        expect(result.buckets[2].object_count).to eq(1)
      end
    end
  end
end
