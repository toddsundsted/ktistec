require "http/client"
require "json"

module Ktistec
  # Base class for translators.
  #
  abstract class Translator
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
        response = HTTP::Client.get(@api_uri.resolve("/v2/languages?type=source"), headers: headers)
        JSON.parse(response.body).as_a.each do |language|
          @source_languages << language["language"].as_s.upcase
        end
        response = HTTP::Client.get(@api_uri.resolve("/v2/languages?type=target"), headers: headers)
        JSON.parse(response.body).as_a.each do |language|
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
        response = HTTP::Client.post(@api_uri.resolve("/v2/translate"), headers: headers, body: body.to_json)
        body = JSON.parse(response.body)
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
        response = HTTP::Client.get(@api_uri.resolve("/languages"), headers: headers)
        JSON.parse(response.body).as_a.each do |language|
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
        response = HTTP::Client.post(@api_uri.resolve("/translate"), headers: headers, body: body.to_json)
        body = JSON.parse(response.body)
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
