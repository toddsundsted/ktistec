require "../backend"

class Feed
  abstract class Backend
    # A judge that is an executable file.
    #
    class Executable < Backend
      getter path : String

      def initialize(@path : String)
      end

      def judge(feed : ::Feed, objects : Array(ActivityPub::Object)) : Array(Judgment | Failure)
        raise PermanentError.new("executable judges can't be asked yet")
      end

      def validate_params(params : Hash(String, JSON::Any)) : Array(String)
        [] of String
      end

      def revision(params : Hash(String, JSON::Any)) : String
        ""
      end

      def cost(params : Hash(String, JSON::Any)) : Cost
        Cost.new(batch_size: 1)
      end
    end
  end
end
