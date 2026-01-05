require "./builder_base"
require "../../models/activity_pub/object/note"

module ObjectBuilder
  # Builds `Note` objects from request parameters.
  #
  class NoteBuilder < BuilderBase
    def build(
      params : Hash(String, String | Array(String)),
      actor : ActivityPub::Actor,
      object : ActivityPub::Object? = nil
    ) : BuildResult
      iri = "#{Ktistec.host}/objects/#{Ktistec::Util.id}"
      note = object || ActivityPub::Object::Note.new(iri: iri)  # intentionally handle any object type
      result = BuildResult.new(note)

      in_reply_to_iri = extract_string(params, "in-reply-to")
      in_reply_to = validate_reply_to(in_reply_to_iri, result)
      addressing = calculate_addressing(params, actor, in_reply_to)
      apply_common_attributes(params, addressing, note, actor, in_reply_to)

      collect_model_errors(note, result)

      result
    end
  end
end
