require "./object_builders/**"
require "../models/activity_pub/actor"
require "../models/activity_pub/object"

module ObjectFactory
  # Builds an ActivityPub object from request parameters.
  #
  # Automatically detects the object type and delegates to the
  # appropriate builder (`NoteBuilder`, `QuestionBuilder`, etc.).
  #
  def self.build_from_params(
    params : Hash(String, String | Array(String)),
    actor : ActivityPub::Actor,
    object : ActivityPub::Object? = nil
  ) : ObjectBuilders::BuildResult
    builder = detect_builder(params)
    builder.build(params, actor, object)
  end

  # Detects which builder to use based on `params`.
  #
  private def self.detect_builder(params : Hash(String, String | Array(String))) : ObjectBuilders::ObjectBuilder
    if params["poll-options"]?
      ObjectBuilders::QuestionBuilder.new
    else
      ObjectBuilders::NoteBuilder.new
    end
  end
end
