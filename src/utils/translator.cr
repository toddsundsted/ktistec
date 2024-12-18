module Ktistec
  # Base class for translators.
  #
  abstract class Translator
    abstract def translate(name : String?, summary : String?, content : String?, source : String, target : String) : \
      {name: String?, summary: String?, content: String?}
  end
end
