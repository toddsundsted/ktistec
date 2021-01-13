require "json"

require "../framework/json_ld"
require "../framework/model"

module ActivityPub
  def initialize(options : Hash, prefix : String = "", ignore_cached = true)
    super(options, prefix: prefix)
    {% begin %}
      {% vs = @type.instance_vars.select { |v| v.annotation(Ktistec::Model::Assignable) || v.annotation(Ktistec::Model::Persistent) } %}
      {% for v in vs %}
        key = prefix + {{v.stringify}}
        if options.keys.any? { |k| k.to_s.starts_with?(key + ".") }
          if (o = ActivityPub.from_hash?(key + ".", options, ignore_cached: ignore_cached)) && o.is_a?(typeof(self.{{v}}))
            self.{{v}} = o
          end
        end
      {% end %}
    {% end %}
  end

  def initialize(**options)
    super(**options)
  end

  def assign(options : Hash, prefix : String = "", ignore_cached = true)
    super(options, prefix: prefix)
    {% begin %}
      {% vs = @type.instance_vars.select { |v| v.annotation(Ktistec::Model::Assignable) || v.annotation(Ktistec::Model::Persistent) } %}
      {% for v in vs %}
        key = prefix + {{v.stringify}}
        if options.keys.any? { |k| k.to_s.starts_with?(key + ".") }
          if (o = ActivityPub.from_hash?(key + ".", options, ignore_cached: ignore_cached)) && o.is_a?(typeof(self.{{v}}))
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

  def self.from_hash(prefix : String, options : Hash, *, default = nil, ignore_cached = true)
    {% begin %}
      key = prefix + "type"
      case options[key]?
      {% for subclass in @type.includers.reduce([] of TypeNode) { |a, t| a + t.all_subclasses << t }.uniq %}
        when {{name = subclass.stringify}}
          key = prefix + "iri"
          (!ignore_cached && options.has_key?(key) ? {{subclass}}.find?(options[key].to_s).try(&.assign(options, prefix: prefix, ignore_cached: ignore_cached)) : nil) ||
            {{subclass}}.new(options, prefix: prefix, ignore_cached: ignore_cached)
      {% end %}
      else
        if default
          key = prefix + "iri"
          (!ignore_cached && options.has_key?(key) ? default.find?(options[key].to_s).try(&.assign(options, prefix: prefix, ignore_cached: ignore_cached)) : nil) ||
            default.new(options, prefix: prefix, ignore_cached: ignore_cached)
        elsif (type = options[key]?)
          raise NotImplementedError.new(type.to_s)
        else
          raise NotImplementedError.new("no type")
        end
      end
    {% end %}
  end

  def self.from_hash?(prefix : String, options : Hash, *, default = nil, ignore_cached = true)
    from_hash(prefix, options, default: default, ignore_cached: ignore_cached)
  rescue NotImplementedError
    nil
  end

  macro included
    def self.from_hash(options, ignore_cached = true)
      ActivityPub.from_hash("", options, default: self, ignore_cached: ignore_cached).as(self)
    end

    def self.from_hash?(options, ignore_cached = true)
      ActivityPub.from_hash?("", options, default: self, ignore_cached: ignore_cached).as(self?)
    rescue TypeCastError
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
      ActivityPub.from_json_ld?(json, **options.merge({default: self})).as(self?)
    rescue TypeCastError
    end
  end
end
