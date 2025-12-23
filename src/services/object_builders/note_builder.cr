require "./object_builder"
require "../../models/activity_pub/object/note"

module ObjectBuilders
  # Builds `Note` objects from request parameters.
  #
  class NoteBuilder < ObjectBuilder
    def build(
      params : Hash(String, String),
      actor : ActivityPub::Actor,
      object : ActivityPub::Object? = nil
    ) : BuildResult
      iri = "#{Ktistec.host}/objects/#{Ktistec::Util.id}"
      note = object || ActivityPub::Object::Note.new(iri: iri)
      result = BuildResult.new(note)
      in_reply_to_iri = extract_string(params, "in-reply-to")
      in_reply_to = validate_reply_to(in_reply_to_iri, result)
      if result.valid?
        addressing = calculate_addressing(params, actor, in_reply_to)
        apply_common_attributes(params, addressing, note, actor, in_reply_to)
        collect_model_errors(note, result)
      end
      result
    end
  end
end
