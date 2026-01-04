module ThreadAnalysisService
  record ThreadAnalysis,
    thread_id : String,
    root_object_id : Int64,
    object_count : Int32,
    author_count : Int32,
    max_depth : Int32,
    timeline_histogram : TimelineHistogram?,
    key_participants : Array(ParticipantInfo),
    notable_branches : Array(BranchInfo),
    duration_ms : Float64

  record ParticipantInfo,
    actor_iri : String,
    object_count : Int32,
    depth_range : Tuple(Int32, Int32),   # min and max depth
    time_range : Tuple(Time, Time),      # first and last seen
    object_ids : Array(Int64)

  record BranchInfo,
    root_id : Int64,
    score : Int32,
    object_count : Int32,
    author_count : Int32,
    depth_range : Tuple(Int32, Int32),   # min and max depth
    time_range : Tuple(Time?, Time?),    # first and last seen
    object_ids : Array(Int64)

  record TimelineHistogram,
    time_range : Tuple(Time, Time),      # active range (outliers excluded)
    total_objects : Int32,               # count of objects in active range
    outliers_excluded : Int32,           # count of objects outside active range
    bucket_size_minutes : Int32,         # granularity of buckets
    buckets : Array(TimeBucket)          # non-empty buckets

  record TimeBucket,
    time_range : Tuple(Time, Time),      # start and end time of bucket
    object_count : Int32,
    cumulative_count : Int32,
    author_count : Int32,                # distinct authors in this bucket
    object_ids : Array(Int64)            # objects in this bucket

  # Returns key participants in the thread based on object data.
  #
  def self.key_participants(
    tuples : Array(NamedTuple),
    limit : Int32 = 18, # matches thread_page_thread_controls.html.slang
  ) : Array(ParticipantInfo)
    by_author = tuples.compact_map do |t|
      if (actor_iri = t[:attributed_to_iri])
        {
          id: t[:id],
          iri: actor_iri,
          depth: t[:depth],
          published: t[:published]
        }
      end
    end.group_by { |t| t[:iri] }

    participants = by_author.map do |actor_iri, objects|
      depths = objects.map { |o| o[:depth] }
      times = objects.compact_map { |o| o[:published] }
      ParticipantInfo.new(
        actor_iri: actor_iri,
        object_count: objects.size,
        depth_range: {depths.min, depths.max},
        time_range: {times.min, times.max},
        object_ids: objects.map { |o| o[:id] }
      )
    end

    op_iri = tuples.find { |t| t[:in_reply_to_iri].nil? }.try(&.dig(:attributed_to_iri))
    op_participant = participants.find { |p| p.actor_iri == op_iri }

    top_n = participants
      .reject { |p| p.actor_iri == op_iri }
      .sort_by! { |p| -p.object_count }
      .first(limit - 1)

    result = [] of ParticipantInfo
    result << op_participant if op_participant
    result.concat(top_n)
    result
  end

  # Returns notable branches (high-activity subtrees) in the thread.
  #
  # A "notable branch" is any reply and its descendants (up to
  # `max_depth`) that form a subtree of more than `threshold` objects.
  #
  def self.notable_branches(
    tuples : Array(NamedTuple),
    threshold : Int32 = 5,
    max_depth : Int32 = 2,
    limit : Int32 = 10
  ) : Array(BranchInfo)
    children_map = {} of String? => Array(typeof(tuples.first))
    children_map = tuples.reduce(children_map) do |map, t|
      parent_iri = t[:in_reply_to_iri]
      map[parent_iri] ||= [] of typeof(tuples.first)
      map[parent_iri] << t
      map
    end

    branches = [] of BranchInfo
    tuples.each do |tuple|
      next if tuple[:in_reply_to_iri].nil?

      subtree_ids = [[tuple[:id]]]
      current_level_iris = [tuple[:iri]]

      max_depth.times do
        next_level_ids = [] of Int64
        next_level_iris = [] of String

        current_level_iris.each do |parent_iri|
          if children = children_map[parent_iri]?
            children.each do |child|
              next_level_ids << child[:id]
              next_level_iris << child[:iri]
            end
          end
        end

        break if next_level_ids.empty?

        subtree_ids << next_level_ids
        current_level_iris = next_level_iris
      end

      next if (score = subtree_ids.flatten.size) < threshold

      # compute branch statistics

      descendant_ids = [tuple[:id]]
      to_visit_iris = [tuple[:iri]]
      visited_iris = Set(String).new

      while !to_visit_iris.empty?
        current_iri = to_visit_iris.shift
        next if visited_iris.includes?(current_iri)
        visited_iris.add(current_iri)
        if (children = children_map[current_iri]?)
          children.each do |child|
            descendant_ids << child[:id]
            to_visit_iris << child[:iri]
          end
        end
      end

      descendant_tuples = descendant_ids.compact_map { |id| tuples.find { |t| t[:id] == id } }

      authors = descendant_tuples.compact_map { |t| t[:attributed_to_iri] }.uniq!
      depths = descendant_tuples.compact_map { |t| t[:depth] }
      times = descendant_tuples.compact_map { |t| t[:published] }.sort!

      branches << BranchInfo.new(
        root_id: tuple[:id],
        score: score,
        object_count: descendant_ids.size,
        author_count: authors.size,
        depth_range: {depths.min, depths.max},
        time_range: times.size > 1 ? {times.first, times.last} : {times.first?, times.first?},
        object_ids: descendant_ids
      )
    end

    root_iris = Set(String).new
    parent_iris = Set(String?).new

    selected = [] of BranchInfo
    branches.sort_by(&.score.-).each do |branch|
      root_tuple = tuples.find { |t| t[:id] == branch.root_id }
      next unless root_tuple

      root_iri = root_tuple[:iri]
      parent_iri = root_tuple[:in_reply_to_iri]

      # skip if this is an immediate child or an immediate parent of
      # an already-selected branch

      next if root_iris.includes?(parent_iri)
      next if parent_iris.includes?(root_iri)

      root_iris.add(root_iri)
      parent_iris.add(parent_iri)

      selected << branch

      break if selected.size >= limit
    end

    selected
  end

  # Returns a timeline histogram showing thread activity over time.
  #
  # Automatically selects appropriate bucket granularity based on thread
  # duration. Uses adaptive outlier detection to exclude stragglers.
  #
  def self.timeline_histogram(
    tuples : Array(NamedTuple)
  ) : TimelineHistogram?
    objects = tuples.compact_map do |t|
      if (published = t[:published])
        {
          id: t[:id],
          published: published,
          attributed_to_iri: t[:attributed_to_iri]
        }
      end
    end

    return nil if objects.size < 2

    objects.sort_by! { |o| o[:published] }

    gaps = [] of Time::Span
    objects.each_cons(2) do |pair|
      gaps << (pair[1][:published] - pair[0][:published])
    end

    sorted_gaps = gaps.sort_by { |g| g.total_seconds }
    median_gap = sorted_gaps[sorted_gaps.size // 2]

    # threshold: minimum 6 hours, or 3x median (whichever is larger)
    outlier_threshold = [median_gap * 3, 6.hours].max

    # identify all clusters
    clusters = [] of Array(typeof(objects.first))
    current_cluster = [objects.first]

    objects.each_cons(2) do |pair|
      gap = pair[1][:published] - pair[0][:published]
      if gap > outlier_threshold
        clusters << current_cluster
        current_cluster = [pair[1]]
      else
        current_cluster << pair[1]
      end
    end
    clusters << current_cluster

    # find last significant cluster (3+ posts) as baseline
    last_significant_cluster = clusters.reverse.find { |c| c.size >= 3 }

    baseline_cutoff = last_significant_cluster ? last_significant_cluster.last[:published] : objects.last[:published]
    baseline_duration = (baseline_cutoff - objects.first[:published]).total_hours
    baseline_bucket_size = calculate_bucket_size_for_duration(baseline_duration)

    # try progressively trimming trailing clusters to improve granularity
    best_cutoff = baseline_cutoff
    best_bucket_size = baseline_bucket_size
    accumulated_loss = 0

    # trim clusters backwards from end
    clusters.reverse.each_with_index do |cluster, idx|
      accumulated_loss += cluster.size
      loss_percentage = accumulated_loss.to_f / objects.size

      # stop if we lose more than 5% of posts
      break if loss_percentage > 0.05

      # find the cluster before this one
      cutoff_cluster_idx = clusters.size - idx - 2
      next if cutoff_cluster_idx < 0

      cutoff_cluster = clusters[cutoff_cluster_idx]
      cutoff_time = cutoff_cluster.last[:published]
      trimmed_duration = (cutoff_time - objects.first[:published]).total_hours
      bucket_size = calculate_bucket_size_for_duration(trimmed_duration)

      # keep this cutoff if it gives us smaller buckets
      if bucket_size < best_bucket_size
        best_cutoff = cutoff_time
        best_bucket_size = bucket_size
      end
    end

    # use the best cutoff found
    active_objects = objects.select { |o| o[:published] <= best_cutoff }
    outlier_count = objects.size - active_objects.size

    return if active_objects.empty?

    time_start = active_objects.first[:published]
    time_end = active_objects.last[:published]
    duration = time_end - time_start

    bucket_size_minutes = best_bucket_size

    bucket_duration = bucket_size_minutes.minutes

    bucket_size_seconds = bucket_size_minutes * 60
    bucket_start = time_start - (time_start.to_unix % bucket_size_seconds).seconds

    buckets_map = Hash(Time, Array({id: Int64, published: Time, attributed_to_iri: String?})).new
    active_objects.each do |object|
      offset_seconds = (object[:published] - bucket_start).total_seconds
      bucket_index = (offset_seconds / bucket_size_seconds).floor.to_i
      object_bucket_start = bucket_start + (bucket_index * bucket_size_seconds).seconds

      buckets_map[object_bucket_start] ||= [] of {id: Int64, published: Time, attributed_to_iri: String?}
      buckets_map[object_bucket_start] << object
    end

    buckets = [] of TimeBucket
    cumulative = 0
    buckets_map.keys.sort!.each do |bucket_start_time|
      bucket_end_time = bucket_start_time + bucket_duration

      bucket_objects = buckets_map[bucket_start_time]
      cumulative += bucket_objects.size

      author_count = bucket_objects.compact_map { |o| o[:attributed_to_iri] }.uniq!.size

      buckets << TimeBucket.new(
        time_range: {bucket_start_time, bucket_end_time},
        object_count: bucket_objects.size,
        cumulative_count: cumulative,
        author_count: author_count,
        object_ids: bucket_objects.map { |o| o[:id] }
      )
    end

    TimelineHistogram.new(
      time_range: {time_start, time_end},
      total_objects: active_objects.size,
      outliers_excluded: outlier_count,
      bucket_size_minutes: bucket_size_minutes,
      buckets: buckets
    )
  end

  # Calculates best bucket size in minutes for a given duration in
  # hours.
  #
  private def self.calculate_bucket_size_for_duration(hours : Float64) : Int32
    case hours
    when 0...1     then 5      # < 1 hour
    when 1...3     then 15     # 1-3 hours
    when 3...12    then 60     # 3-12 hours (1 hour)
    when 12...24   then 180    # 12-24 hours (3 hours)
    when 24...72   then 360    # 1-3 days (6 hours)
    when 72...168  then 720    # 3-7 days (12 hours)
    when 168...672 then 1440   # 1-4 weeks (daily)
    else                10080  # > 4 weeks (weekly)
    end
  end
end
