require "db"
require "sqlite3"

require "../executable"
require "../../../../serializers/feed"
require "../../../../serializers/post"

class Feed
  abstract class Backend
    class Executable < Backend
      # Defines what an executable judge reads its questions from and
      # writes its answers to.
      #
      module Exchange
        extend self

        VERSION = 1

        SCHEMA = [
          "CREATE TABLE feed (name TEXT, description TEXT, params TEXT)",
          "CREATE TABLE posts (iri TEXT PRIMARY KEY, content TEXT)",
          <<-SQL,
          CREATE TABLE answers (
            iri TEXT PRIMARY KEY REFERENCES posts(iri),
            included INTEGER,
            failure TEXT CHECK (failure IN ('transient', 'permanent')),
            reason TEXT,
            CHECK ((included IS NULL) <> (failure IS NULL))
          )
          SQL
        ]

        struct Answer
          include DB::Serializable

          getter iri : String
          getter included : Bool?
          getter failure : String?
          getter reason : String?

          def to_answer : Judgment | Failure
            included, failure = @included, @failure
            if !included.nil? && failure.nil?
              Judgment.new(included: included, reason: reason)
            elsif failure && (kind = Failure::Kind.parse?(failure))
              Failure.new(kind, reason)
            else
              Failure.new(:transient, "malformed answer")
            end
          end
        end

        # Writes the questions about `objects` for `feed`.
        #
        def write(path : String, feed : ::Feed, objects : Array(ActivityPub::Object)) : Nil
          DB.open("sqlite3://#{path}") do |db|
            db.exec("PRAGMA user_version = #{VERSION}")
            SCHEMA.each { |sql| db.exec(sql) }
            serialized_feed = Serializers::Feed.from(feed)
            db.exec("INSERT INTO feed (name, description, params) VALUES (?, ?, ?)", serialized_feed.name, serialized_feed.description, serialized_feed.params.to_json)
            objects.each do |object|
              serialized_post = Serializers::Post.from(object)
              db.exec("INSERT INTO posts (iri, content) VALUES (?, ?)", serialized_post.iri, serialized_post.content)
            end
          end
        end

        # Reads the answers, by IRI.
        #
        def read(path : String) : Hash(String, Judgment | Failure)
          DB.open("sqlite3://#{path}") do |db|
            answers = Answer.from_rs(db.query("SELECT iri, included, failure, reason FROM answers"))
            answers.to_h { |answer| {answer.iri, answer.to_answer} }
          end
        end
      end
    end
  end
end
