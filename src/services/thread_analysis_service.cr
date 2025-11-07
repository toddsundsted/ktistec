module ThreadAnalysisService
  record ParticipantInfo,
    actor_iri : String,
    object_count : Int32,
    depth_range : Tuple(Int32, Int32),   # min and max depth
    time_range : Tuple(Time, Time),      # first and last seen
    object_ids : Array(Int64)

  record BranchInfo,
    root_id : Int64,
    object_count : Int32,
    author_count : Int32,
    depth_range : Tuple(Int32, Int32),   # min and max depth
    time_range : Tuple(Time?, Time?),    # first and last seen
    object_ids : Array(Int64)

  # Returns key participants in the thread based on object data.
  #
  def self.key_participants(
    tuples : Array(NamedTuple),
    limit : Int32 = 5,
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
      .sort_by { |p| -p.object_count }
      .first(limit)

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

      subtree_ids = subtree_ids.flatten

      next if subtree_ids.size < threshold

      # compute branch statistics

      subtree_tuples = subtree_ids.compact_map { |id| tuples.find { |t| t[:id] == id } }

      authors = subtree_tuples.compact_map { |t| t[:attributed_to_iri] }.uniq
      depths = subtree_tuples.compact_map { |t| t[:depth] }
      times = subtree_tuples.compact_map { |t| t[:published] }.sort

      branches << BranchInfo.new(
        root_id: tuple[:id],
        object_count: subtree_ids.size,
        author_count: authors.size,
        depth_range: {depths.min, depths.max},
        time_range: times.size > 1 ? {times.first, times.last} : {times.first?, times.first?},
        object_ids: subtree_ids
      )
    end

    branches.sort_by { |b| -b.object_count }.first(limit)
  end
end
