require "./build_result"
require "../../models/activity_pub/actor"
require "../../models/activity_pub/object"
require "../../views/view_helper"

module ObjectBuilders
  # Abstract base class for object builders.
  #
  # Each builder implements type-specific logic for constructing
  # ActivityPub objects from request parameters.
  #
  abstract class ObjectBuilder
    # Builds an ActivityPub object.
    #
    # Returns a `BuildResult` containing the object and validation
    # errors.
    #
    abstract def build(
      params : Hash(String, String | Array(String)),
      actor : ActivityPub::Actor,
      object : ActivityPub::Object? = nil
    ) : BuildResult

    # Extracts a string parameter.
    #
    # Returns `nil` if the parameter is not present or is blank.
    #
    protected def extract_string(params : Hash(String, String | Array(String)), key : String) : String?
      params[key]?.try(&.as(String).strip.presence)
    end

    # Extracts a boolean parameter.
    #
    # Returns `true` if the parameter value is "true", `false` otherwise.
    #
    protected def extract_boolean(params : Hash(String, String | Array(String)), key : String) : Bool
      !!params[key]?.try { |value| value.as(String) == "true" }
    end

    # Extracts an integer parameter.
    #
    # Returns `nil` if the parameter is not present or cannot be
    # converted to an integer.
    #
    protected def extract_integer(params : Hash(String, String | Array(String)), key : String) : Int32?
      params[key]?.try(&.as(String).to_i?)
    end

    # Extracts an array parameter.
    #
    # Returns `nil` if the parameter is not present.
    #
    protected def extract_array(params : Hash(String, String | Array(String)), key : String) : Array(String)?
      if (value = params[key]?) && value.is_a?(Array(String))
        value
      end
    end

    # Calculates addressing (visibility, to, cc, audience) for an object.
    #
    # Handles reply-to author and recipient merging.
    #
    protected def calculate_addressing(
      params : Hash(String, String | Array(String)),
      actor : ActivityPub::Actor,
      in_reply_to : ActivityPub::Object? = nil
    ) : NamedTuple(visible: Bool, to: Set(String), cc: Set(String), audience: Array(String)?)
      visible, to, cc = Ktistec::ViewHelper.addressing(params, actor)

      if in_reply_to && (attributed_to = in_reply_to.attributed_to?)
        to << attributed_to.iri
      end

      if (to_param = extract_string(params, "to"))
        to |= to_param.split(",").map(&.strip).to_set
      end
      if (cc_param = extract_string(params, "cc"))
        cc |= cc_param.split(",").map(&.strip).to_set
      end

      audience = in_reply_to.try(&.audience)

      {visible: visible, to: to, cc: cc, audience: audience}
    end

    # Applies common object attributes from parameters.
    #
    protected def apply_common_attributes(
      params : Hash(String, String | Array(String)),
      addressing : NamedTuple(visible: Bool, to: Set(String), cc: Set(String), audience: Array(String)?),
      object : ActivityPub::Object,
      actor : ActivityPub::Actor,
      in_reply_to : Object? = nil
    )
      content = extract_string(params, "content") || ""
      media_type = extract_string(params, "media-type") || "text/html; editor=trix"
      language = extract_string(params, "language")
      name = extract_string(params, "name")
      summary = extract_string(params, "summary")
      sensitive = extract_boolean(params, "sensitive")
      canonical_path = extract_string(params, "canonical-path")

      object.assign(
        source: ActivityPub::Object::Source.new(content, media_type),
        attributed_to_iri: actor.iri,
        attributed_to: actor,
        in_reply_to_iri: in_reply_to.try(&.iri),
        replies_iri: "#{object.iri}/replies",
        language: language,
        name: name,
        summary: summary,
        sensitive: sensitive,
        canonical_path: canonical_path,
        visible: addressing[:visible],
        to: addressing[:to].to_a,
        cc: addressing[:cc].to_a,
        audience: addressing[:audience],
      )
    end

    # Validates that `in_reply_to` exists.
    #
    # Returns the object if found, `nil` otherwise. Adds an error to
    # the result if not found.
    #
    protected def validate_reply_to(
      in_reply_to_iri : String?,
      result : BuildResult
    ) : ActivityPub::Object?
      return nil unless in_reply_to_iri
      in_reply_to = ActivityPub::Object.find?(in_reply_to_iri)
      unless in_reply_to
        result.add_error("in_reply_to", "object not found")
      end
      in_reply_to
    end

    # Collects model validation errors.
    #
    # Adds validation errors from the model to the build result.
    #
    protected def collect_model_errors(
      model : Ktistec::Model,
      result : BuildResult
    )
      unless model.valid?
        model.errors.each do |field, messages|
          messages.each { |message| result.add_error(field, message) }
        end
      end
    end
  end
end
