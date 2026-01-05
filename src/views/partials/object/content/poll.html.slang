crystal:
  question = poll.question
  if (is_anonymous = !env.account?)
    tallies = {options: poll.options, voters_count: poll.voters_count}
    voted_options = [] of String
    is_author = false
  else
    tallies = poll.adjust_votes(question, env.account.actor)
    voted_options = question.options_by(env.account.actor)
    is_author = question.attributed_to_iri == env.account.actor.iri
  end
  is_draft = question.draft?
  is_expired = poll.expired?
  has_voted = !voted_options.empty?
  is_disabled = show_results = is_expired || has_voted || is_anonymous || (is_author && !is_draft)
  votes_count = tallies[:options].sum(&.votes_count)
turbo-frame.ui.segment.poll id="poll-#{question.id}" data-controller="poll" data-poll-id=question.id data-turbo-permanent=true
  form.poll-vote-form method="post" action="/polls/#{question.id}/vote" data-poll-target="voteForm"
    == authenticity_token(env)
    - options_classes = [has_voted ? "voted" : nil, is_disabled ? "disabled" : nil].compact.join(" ")
    .poll-options class=options_classes
      - tallies[:options].each do |option|
        - voted = voted_options.includes?(option.name)
        .poll-option class=(voted ? "voted" : "")
          label
            - if poll.multiple_choice
              - if is_disabled
                input type="checkbox" name="options" value=option.name disabled="disabled" checked=voted
              - else
                input type="checkbox" name="options" value=option.name data-action="poll#optionSelected"
            - else
              - if is_disabled
                input type="radio" name="options" value=option.name disabled="disabled" checked=voted
              - else
                input type="radio" name="options" value=option.name data-action="poll#optionSelected"
            span.option-name
              == s Ktistec::Emoji.emojify(option.name, object_emojis)
          - if show_results
            .poll-option-votes
              - option_count = option.votes_count
              - percent = votes_count > 0 ? ((option_count.to_f / votes_count.to_f) * 100).round(1) : 0
              span.poll-count = option_count
              .poll-option-bar
                .poll-option-bar-fill style="width: #{percent}%"
          - else
            .poll-option-votes
              .poll-option-bar
    .poll-footer
      - if is_disabled
        button.ui.tiny.primary.button type="submit" disabled="disabled"
          | Vote
      - elsif is_draft && is_author
        button.ui.tiny.primary.button type="button" data-poll-target="voteButton"
          | Vote
      - else
        button.ui.tiny.primary.button type="submit" data-poll-target="voteButton"
          | Vote
      - if is_expired
        span.poll-status.expired Poll ended
        - if (closed_at = poll.closed_at) && timezone
          span.poll-closed-time = closed_at.in(timezone).to_s("%b %d, %Y")
      - elsif (closed_at = poll.closed_at)
        span.poll-status.active
          | Ends #{distance_of_time_in_words(closed_at - Time.utc)} from now
      - if (voters_count = tallies[:voters_count]) && voters_count > 0
        span.poll-voters
          = pluralize(voters_count, "voter")
      - elsif votes_count > 0
        span.poll-voters
          = pluralize(votes_count, "vote")
      - if poll.multiple_choice
        span.poll-type
          | Multiple choice
