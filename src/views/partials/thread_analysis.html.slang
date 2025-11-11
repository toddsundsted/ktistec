turbo-frame#thread_analysis
  crystal:
    key_participants = analysis.key_participants
    timeline_histogram = analysis.timeline_histogram
    notable_branches = analysis.notable_branches

  .contributors role="region" aria-label="Thread key contributors"
    p Contributors to this thread
    div
      - key_participants.truncate(0, 18).each do |participant|
        - if (actor = ActivityPub::Actor.find?(iri: participant.actor_iri))
          - if (icon = actor.icon)
            a.ui.avatar.image data-turbo-frame="_top" href=remote_actor_path(actor) aria-label="#{actor.display_name}, #{pluralize(participant.object_count, "post")}"
              img data-actor-id=actor.id src=icon alt="#{actor.display_name}"

  - unless timeline_histogram.nil?
    crystal:
      time_range = {timeline_histogram.time_range[0], timeline_histogram.time_range[1]}
      duration_hours = ((time_range[1] - time_range[0]).total_minutes / 60).round(1)
      total_posts = timeline_histogram.buckets.sum(&.object_count)
      # check if thread spans multiple days
      timezone = Time::Location.load(env.account.timezone)
      spans_days = (time_range[1].in(timezone).to_s("%Y-%m-%d") != time_range[0].in(timezone).to_s("%Y-%m-%d"))
      labels = timeline_histogram.buckets.map do |bucket|
        spans_days ? bucket.time_range[0].in(timezone).to_s("%m/%d %I:%M%p") : bucket.time_range[0].in(timezone).to_s("%I:%M%p")
      end
      datasets = [{
        label: "Posts",
        data: timeline_histogram.buckets.map(&.object_count),
        borderWidth: 1,
        borderRadius: 3,
        type: "bar"
      }]
      options = {
        plugins: {
          legend: {
            display: false
          }
        },
        maintainAspectRatio: false
      }
    .timeline style="margin-top: 15px;" role="region" aria-label="Thread timeline visualization"
      p Thread Timeline (#{analysis.object_count} posts over #{duration_hours} hours)
      canvas data-controller="chart" style="max-height: 150px; margin: 10px 0;" role="img" aria-label="Activity histogram showing #{total_posts} posts over time"
        script type="application/json" data-chart-target="labels"
          == labels.to_json
        script type="application/json" data-chart-target="datasets"
          == datasets.to_json
        script type="application/json" data-chart-target="options"
          == options.to_json

  - unless notable_branches.empty?
    .branches style="margin-top: 15px;" role="region" aria-label="Thread notable branches"
      p Notable Branches
      .ui.list
        - notable_branches.each_with_index do |branch, index|
          - if (branch_root = ActivityPub::Object.find?(branch.root_id)) && (preview = branch_root.preview)
            .item role="listitem"
              - if (attributed_to = branch_root.attributed_to?) && (icon = attributed_to.icon)
                img.ui.avatar.image data-actor-id=attributed_to.id src=icon alt="#{attributed_to.display_name}"
              .content style="width: calc(100% - 2em)"
                .header
                  a data-turbo-frame="_top" href=remote_branch_path(branch_root) aria-label="View branch #{index + 1}"
                    = attributed_to.try(&.display_name)
                .truncated.description
                  = t preview
