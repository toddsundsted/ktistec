require "http/client"
require "json"

module Ktistec
  # Base class for translators.
  #
  abstract class Translator
    MAX_LANGUAGES_RESPONSE_BYTES =    65_536
    MAX_TRANSLATE_RESPONSE_BYTES = 1_048_576

    REQUEST_TIMEOUT = 30.seconds

    class Error < Exception
    end

    # Performs an HTTP GET against `uri`, returning the response body.
    #
    # The connection is bounded by `REQUEST_TIMEOUT`. The body is
    # capped at `max_bytes`: responses whose `Content-Length` exceeds
    # the cap are rejected.
    #
    private def bounded_get(uri : URI, headers : HTTP::Headers, *, max_bytes : Int32) : String
      result = ""
      client = make_client(uri)
      client.get(uri.request_target, headers) do |response|
        result = read_response(response, uri, max_bytes)
      end
      result
    ensure
      client.try(&.close)
    end

    # Performs an HTTP POST against `uri`, returning the response body.
    #
    # The connection is bounded by `REQUEST_TIMEOUT`. The body is
    # capped at `max_bytes`: responses whose `Content-Length` exceeds
    # the cap are rejected.
    #
    private def bounded_post(uri : URI, headers : HTTP::Headers, body : String, *, max_bytes : Int32) : String
      result = ""
      client = make_client(uri)
      client.post(uri.request_target, headers, body) do |response|
        result = read_response(response, uri, max_bytes)
      end
      result
    ensure
      client.try(&.close)
    end

    private def make_client(uri : URI) : HTTP::Client
      client = HTTP::Client.new(uri)
      client.connect_timeout = REQUEST_TIMEOUT
      client.read_timeout = REQUEST_TIMEOUT
      client.write_timeout = REQUEST_TIMEOUT
      client
    end

    private def read_response(response, uri : URI, max_bytes : Int32) : String
      if (content_length = response.headers["Content-Length"]?) && (n = content_length.to_i?) && n > max_bytes
        raise Error.new("Response body too large [Content-Length=#{n} > #{max_bytes}]: #{uri}")
      end
      if (io = response.body_io?)
        buf = IO::Memory.new
        bytes = IO.copy(io, buf, max_bytes + 1)
        if bytes > max_bytes
          raise Error.new("Response body too large [>#{max_bytes} bytes]: #{uri}")
        end
        buf.to_s
      else
        ""
      end
    end

    abstract def translate(name : String?, summary : String?, content : String?, source : String, target : String) : {name: String?, summary: String?, content: String?}

    # Client for DeepL translation.
    #
    class DeepLTranslator < Translator
      Log = ::Log.for("translator.deep_l")

      DEEPL_API      = "https://api.deepl.com/v2/translate"
      DEEPL_FREE_API = "https://api-free.deepl.com/v2/translate"

      @source_languages = Set(String).new
      @target_languages = Set(String).new

      getter api_uri : URI

      def initialize(@api_uri : URI, @api_key : String)
        headers = HTTP::Headers{
          "Accept"        => "application/json",
          "Authorization" => "DeepL-Auth-Key #{@api_key}",
        }
        body = bounded_get(@api_uri.resolve("/v2/languages?type=source"), headers, max_bytes: MAX_LANGUAGES_RESPONSE_BYTES)
        JSON.parse(body).as_a.each do |language|
          @source_languages << language["language"].as_s.upcase
        end
        body = bounded_get(@api_uri.resolve("/v2/languages?type=target"), headers, max_bytes: MAX_LANGUAGES_RESPONSE_BYTES)
        JSON.parse(body).as_a.each do |language|
          @target_languages << language["language"].as_s.upcase
        end
      end

      def translate(name : String?, summary : String?, content : String?, source : String, target : String) : {name: String?, summary: String?, content: String?}
        headers = HTTP::Headers{
          "Content-Type"  => "application/json",
          "Authorization" => "DeepL-Auth-Key #{@api_key}",
        }
        body = {
          "text"         => [name, summary, content].compact,
          "tag_handling" => "html",
        }
        add_source(body, source)
        add_target(body, target)
        Log.debug { body }
        body = JSON.parse(bounded_post(@api_uri.resolve("/v2/translate"), headers, body.to_json, max_bytes: MAX_TRANSLATE_RESPONSE_BYTES))
        Log.debug { body }
        texts = body["translations"].as_a.map(&.dig("text"))
        {
          name:    name ? texts.shift.as_s : nil,
          summary: summary ? texts.shift.as_s : nil,
          content: content ? texts.shift.as_s : nil,
        }
      end

      private def add_source(hash, source)
        source = source.upcase
        split_source = source.split("-").first
        if @source_languages.includes?(source) || @source_languages.includes?(split_source)
          hash["source_lang"] = split_source
        end
      end

      private def add_target(hash, target)
        target = target.upcase
        if @target_languages.includes?(target)
          hash["target_lang"] = target
        else
          hash["target_lang"] = target.split("-").first
        end
      end
    end

    # Client for LibreTranslate translation.
    #
    class LibreTranslateTranslator < Translator
      Log = ::Log.for("translator.libre_translate")

      LIBRETRANSLATE_API = "https://libretranslate.com/translate"

      @source_languages = Set(String).new
      @target_languages = Set(String).new

      getter api_uri : URI

      def initialize(@api_uri : URI, @api_key : String)
        headers = HTTP::Headers{
          "Content-Type" => "application/json",
        }
        body = bounded_get(@api_uri.resolve("/languages"), headers, max_bytes: MAX_LANGUAGES_RESPONSE_BYTES)
        JSON.parse(body).as_a.each do |language|
          @source_languages.add language["code"].as_s.downcase
          @target_languages.concat language["targets"].as_a.map(&.as_s.downcase)
        end
      end

      def translate(name : String?, summary : String?, content : String?, source : String, target : String) : {name: String?, summary: String?, content: String?}
        headers = HTTP::Headers{
          "Content-Type" => "application/json",
        }
        body = {
          "q"       => [name, summary, content].compact,
          "format"  => "html",
          "api_key" => @api_key,
        }
        add_source(body, source)
        add_target(body, target)
        Log.debug { body.reject("api_key") }
        body = JSON.parse(bounded_post(@api_uri.resolve("/translate"), headers, body.to_json, max_bytes: MAX_TRANSLATE_RESPONSE_BYTES))
        Log.debug { body }
        texts = body["translatedText"].as_a
        {
          name:    name ? texts.shift.as_s : nil,
          summary: summary ? texts.shift.as_s : nil,
          content: content ? texts.shift.as_s : nil,
        }
      end

      private def add_source(hash, source)
        source = source.downcase
        split_source = source.split("-").first
        if @source_languages.includes?(source) || @source_languages.includes?(split_source)
          hash["source"] = split_source
        else
          hash["source"] = "auto"
        end
      end

      private def add_target(hash, target)
        target = target.downcase
        hash["target"] = target.split("-").first
      end
    end
  end
end
