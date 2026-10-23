require "db"
require "sqlite3"

require "../executable"
require "../../../../serializers/author"
require "../../../../serializers/feed"
require "../../../../serializers/post"
require "../../../../serializers/stats"

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
          "CREATE TABLE stats (posting_rate_q1 REAL, posting_rate_median REAL, posting_rate_q3 REAL)",
          <<-SQL,
          CREATE TABLE authors (
            iri TEXT PRIMARY KEY,
            type TEXT,
            handle TEXT,
            followed INTEGER,
            rate_7 REAL,
            rate_30 REAL,
            rate_90 REAL
          )
          SQL
          <<-SQL,
          CREATE TABLE posts (
            iri TEXT PRIMARY KEY,
            type TEXT,
            name TEXT,
            summary TEXT,
            content TEXT,
            audience TEXT,
            attachments TEXT,
            published TEXT,
            in_reply_to TEXT,
            thread TEXT,
            quote TEXT,
            language TEXT,
            sensitive INTEGER,
            hashtags TEXT,
            mentions TEXT,
            author TEXT REFERENCES authors(iri)
          )
          SQL
          <<-SQL,
          CREATE TABLE answers (
            iri TEXT PRIMARY KEY REFERENCES posts(iri),
            included INTEGER,
            failure TEXT CHECK (failure IN ('transient', 'permanent')),
            reason TEXT,
            CHECK ((included IS NULL) <> (failure IS NULL))
          )
          SQL
          <<-SQL,
          CREATE TABLE unavailable (
            reason TEXT,
            retry_after TEXT
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

        struct Unavailable
          include DB::Serializable

          getter reason : String?

          getter retry_after : Time?
        end

        # Writes the questions about `objects` for `feed`.
        #
        # Stats are computed over windows ending at `now`.
        #
        def write(path : String, feed : ::Feed, objects : Array(ActivityPub::Object), now : Time = Time.utc) : Nil
          DB.open("sqlite3://#{path}") do |db|
            db.exec("PRAGMA user_version = #{VERSION}")
            SCHEMA.each { |sql| db.exec(sql) }
            serialized_feed = Serializers::Feed.from(feed)
            db.exec("INSERT INTO feed (name, description, params) VALUES (?, ?, ?)", serialized_feed.name, serialized_feed.description, serialized_feed.params.to_json)
            serialized_stats = Serializers::Stats.from(feed.owner_iri, now)
            db.exec(
              "INSERT INTO stats (posting_rate_q1, posting_rate_median, posting_rate_q3) VALUES (?, ?, ?)",
              serialized_stats.posting_rate.q1,
              serialized_stats.posting_rate.median,
              serialized_stats.posting_rate.q3,
            )
            objects.compact_map(&.attributed_to?(include_deleted: true)).uniq!(&.iri).each do |actor|
              serialized_author = Serializers::Author.from(actor, feed.owner_iri, now)
              db.exec(
                "INSERT INTO authors (iri, type, handle, followed, rate_7, rate_30, rate_90) VALUES (?, ?, ?, ?, ?, ?, ?)",
                serialized_author.iri,
                serialized_author.type,
                serialized_author.handle,
                serialized_author.followed,
                serialized_author.rate_7,
                serialized_author.rate_30,
                serialized_author.rate_90,
              )
            end
            objects.each do |object|
              serialized_post = Serializers::Post.from(object)
              db.exec(
                "INSERT INTO posts (iri, type, name, summary, content, audience, attachments, published, in_reply_to, thread, quote, language, sensitive, hashtags, mentions, author) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                serialized_post.iri,
                serialized_post.type,
                serialized_post.name,
                serialized_post.summary,
                serialized_post.content,
                serialized_post.audience.to_json,
                serialized_post.attachments.to_json,
                serialized_post.published,
                serialized_post.in_reply_to,
                serialized_post.thread,
                serialized_post.quote,
                serialized_post.language,
                serialized_post.sensitive,
                serialized_post.hashtags.to_json,
                serialized_post.mentions.to_json,
                serialized_post.author,
              )
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

        # Reads whether the judge reported that it is unavailable.
        #
        def unavailable(path : String) : Unavailable?
          DB.open("sqlite3://#{path}") do |db|
            Unavailable.from_rs(db.query("SELECT reason, retry_after FROM unavailable ORDER BY rowid LIMIT 1")).first?
          end
        end
      end
    end
  end
end
