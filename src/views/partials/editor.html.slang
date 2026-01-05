crystal:
  id = object.id || "new"
  has_errors = !object.errors.empty?
  canonical_path_errors = object.errors["canonical_path.from_iri"]?
  must_be_absolute = canonical_path_errors.try(&.includes?("must be absolute"))
  must_not_route = canonical_path_errors.try(&.includes?("must not match an existing route"))
  must_be_unique = canonical_path_errors.try(&.includes?("must be unique"))
  content = object.source.try(&.content) || object.content || nil
  actor = env.account.actor
  if (in_reply_to = object.in_reply_to?)
    ancestors = in_reply_to.ancestors
    mentions = (ancestors.map(&.attributed_to.handle).compact.uniq - [actor.handle]).map { |a| "@#{a} " }.join
    content ||= mentions
  end
  unless (media_type = object.source.try(&.media_type))
    if object.new_record?
      media_type = env.account.default_editor || "text/html; editor=trix"
    else
      media_type = "text/html; editor=trix"
    end
  end
- if media_type.starts_with?("text/markdown")
  == render "src/views/partials/editor/markdown.html.slang"
- else
  == render "src/views/partials/editor/trix.html.slang"
