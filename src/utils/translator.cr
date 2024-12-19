require "http/client"
require "json"

module Ktistec
  # Base class for translators.
  #
  abstract class Translator
    abstract def translate(name : String?, summary : String?, content : String?, source : String, target : String) : \
      {name: String?, summary: String?, content: String?}

    # Client for DeepL translation.
    #
    class DeepLTranslator < Translator
      Log = ::Log.for("translator.deep_l")

      DEEPL_API = "https://api.deepl.com/v2/translate"
      DEEPL_FREE_API = "https://api-free.deepl.com/v2/translate"

      def initialize(@api_url : String, @api_key : String)
      end

      def translate(name : String?, summary : String?, content : String?, source : String, target : String) : \
         {name: String?, summary: String?, content: String?}
        headers = HTTP::Headers{
          "Content-Type" => "application/json",
          "Authorization" => "DeepL-Auth-Key #{@api_key}"
        }
        body = {
          "text" => [name, summary, content].compact,
          "source_lang" => source.split("-").first,
          "target_lang" => target.split("-").first,
          "tag_handling" => "html",
        }.to_json
        Log.debug { body }
        response = HTTP::Client.post(@api_url, headers: headers, body: body)
        body = response.body
        Log.debug { body }
        texts = JSON.parse(body)["translations"].as_a.map(&.dig("text"))
        {
          name: name ? texts.shift.as_s : nil,
          summary: summary ? texts.shift.as_s : nil,
          content: content ? texts.shift.as_s : nil,
        }
      end
    end

    # Client for LibreTranslate translation.
    #
    class LibreTranslateTranslator < Translator
      Log = ::Log.for("translator.libre_translate")

      LIBRETRANSLATE_API = "https://libretranslate.com/translate"

      def initialize(@api_url : String, @api_key : String)
      end

      def translate(name : String?, summary : String?, content : String?, source : String, target : String) : \
         {name: String?, summary: String?, content: String?}
        headers = HTTP::Headers{
          "Content-Type" => "application/json",
        }
        body = {
          "q" => [name, summary, content].compact,
          "source" => source.split("-").first,
          "target" => target.split("-").first,
          "format" => "html",
          "api_key" => @api_key,
        }.to_json
        Log.debug { body.gsub(/"api_key":"[a-f0-9-]+"/, %q|"api_key":"****"|) }
        response = HTTP::Client.post(@api_url, headers: headers, body: body)
        body = response.body
        Log.debug { body }
        texts = JSON.parse(body)["translatedText"].as_a
        {
          name: name ? texts.shift.as_s : nil,
          summary: summary ? texts.shift.as_s : nil,
          content: content ? texts.shift.as_s : nil,
        }
      end
    end
  end
end
