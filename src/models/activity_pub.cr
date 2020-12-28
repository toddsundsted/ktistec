require "json"

require "../framework/json_ld"
require "../framework/model"

module ActivityPub
  def initialize(prefix : String, options : Hash)
    super(prefix, options)
    {% begin %}
      {% vs = @type.instance_vars.select { |v| v.annotation(Ktistec::Model::Assignable) || v.annotation(Ktistec::Model::Persistent) } %}
      {% for v in vs %}
        key = prefix + {{v.stringify}}
        if options.keys.any? { |k| k.to_s.starts_with?(key + ".") }
          if (o = ActivityPub.from_hash?(key + ".", options, default: nil)) && o.is_a?(typeof(self.{{v}}))
            self.{{v}} = o
          end
        end
      {% end %}
    {% end %}
  end

  def initialize(**options)
    super(**options)
  end

  def assign(prefix : String, options : Hash)
    super(prefix, options)
    {% begin %}
      {% vs = @type.instance_vars.select { |v| v.annotation(Ktistec::Model::Assignable) || v.annotation(Ktistec::Model::Persistent) } %}
      {% for v in vs %}
        key = prefix + {{v.stringify}}
        if options.keys.any? { |k| k.to_s.starts_with?(key + ".") }
          if (o = ActivityPub.from_hash?(key + ".", options, default: nil)) && o.is_a?(typeof(self.{{v}}))
            self.{{v}} = o
          end
        end
      {% end %}
    {% end %}
    self
  end

  def assign(**options)
    super(**options)
  end

  def self.from_hash(prefix : String, options : Hash, *, default = nil)
    {% begin %}
      key = prefix + "type"
      case options[key]?
      {% for subclass in @type.includers.reduce([] of TypeNode) { |a, t| a + t.all_subclasses << t }.uniq %}
        when {{name = subclass.stringify}}
          {{subclass}}.find?(options["iri"]?.try(&.to_s)).try(&.assign(prefix, options)) ||
            {{subclass}}.new(prefix, options)
      {% end %}
      else
        if default
          default.find?(options["iri"]?.try(&.to_s)).try(&.assign(prefix, options)) ||
            default.new(prefix, options)
        elsif (type = options[key]?)
          raise NotImplementedError.new(type.to_s)
        else
          raise NotImplementedError.new("no type")
        end
      end
    {% end %}
  end

  def self.from_hash?(prefix : String, options : Hash, *, default = nil)
    from_hash(prefix, options, default: default)
  rescue NotImplementedError
    nil
  end

  macro included
    def self.from_hash(options)
      ActivityPub.from_hash("", options, default: self).as(self)
    end

    def self.from_hash?(options)
      ActivityPub.from_hash?("", options, default: self).as(self)
    end
  end

  def self.from_json_ld(json, **options)
    json = Ktistec::JSON_LD.expand(JSON.parse(json)) if json.is_a?(String | IO)
    {% begin %}
      case json["@type"]?.try(&.as_s.split("#").last)
      {% for subclass in @type.includers.reduce([] of TypeNode) { |a, t| a + t.all_subclasses << t }.uniq %}
        when {{name = subclass.stringify.split("::").last}}
          {% id = name.downcase.id %}
          attrs = {{subclass}}.map(json, **options)
          {{subclass}}.find?(json["@id"]?.try(&.as_s)).try(&.assign(**attrs)) ||
            {{subclass}}.new(**attrs)
      {% end %}
      else
        if (default = options[:default]?)
          attrs = default.map(json, **options)
          default.find?(json["@id"]?.try(&.as_s)).try(&.assign(**attrs)) ||
            default.new(**attrs)
        elsif (type = json["@type"]?)
          raise NotImplementedError.new(type.as_s)
        else
          raise NotImplementedError.new("no type")
        end
      end
    {% end %}
  end

  def self.from_json_ld?(json, **options)
    from_json_ld(json, **options)
  rescue NotImplementedError
    nil
  end

  macro included
    def self.from_json_ld(json, **options)
      ActivityPub.from_json_ld(json, **options.merge({default: self})).as(self)
    end

    def self.from_json_ld?(json, **options)
      ActivityPub.from_json_ld?(json, **options.merge({default: self})).as(self)
    end
  end
end
