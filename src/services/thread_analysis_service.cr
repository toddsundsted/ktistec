module ThreadAnalysisService
  record ParticipantInfo,
    actor_iri : String,
    object_count : Int32,
    depth_range : Tuple(Int32, Int32),   # min and max depth
    time_range : Tuple(Time, Time),      # first and last seen
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
end
