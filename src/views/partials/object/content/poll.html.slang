crystal:
  total = poll.options.sum(&.votes_count)
.ui.segment.poll
  .poll-options
    - poll.options.each do |option|
      .poll-option
        .poll-option-name
          == s Ktistec::Emoji.emojify(option.name, object_emojis)
        .poll-option-votes
          - votes = option.votes_count
          - percentage = total > 0 ? ((votes.to_f / total) * 100).round(1) : 0
          span.count = votes
          span.percentage = "#{percentage}%"
        .poll-option-bar
          .poll-option-bar-fill style="width: #{percentage}%"
  .poll-footer
    - if poll.expired?
      span.poll-status.expired Poll ended
      - if (closed_at = poll.closed_at) && timezone
        span.poll-closed-time = closed_at.in(timezone).to_s("%b %d, %Y")
    - elsif (closed_at = poll.closed_at)
      span.poll-status.active
        | Ends #{distance_of_time_in_words(closed_at - Time.utc)} from now
    - if (voters = poll.voters_count) && voters > 0
      span.poll-voters
        = pluralize(voters, "voter")
    - elsif total > 0
      span.poll-voters
        = pluralize(total, "vote")
    - if poll.multiple_choice
      span.poll-type
        | Multiple choice
