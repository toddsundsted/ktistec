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

        # The columns of `posts` and of `referenced`.
        #
        private POST_COLUMNS = <<-SQL
          iri TEXT PRIMARY KEY,
          type TEXT,
          name TEXT,
          summary TEXT,
          content TEXT,
          "to" TEXT,
          "cc" TEXT,
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
          labels TEXT,
          author TEXT REFERENCES authors(iri),
          deleted INTEGER,
          blocked INTEGER,
          timeline TEXT,
          poll TEXT
          SQL

        SCHEMA = [
          "CREATE TABLE feed (name TEXT, description TEXT, params TEXT)",
          "CREATE TABLE stats (posting_rate_q1 REAL, posting_rate_median REAL, posting_rate_q3 REAL)",
          <<-SQL,
          CREATE TABLE authors (
            iri TEXT PRIMARY KEY,
            type TEXT,
            handle TEXT,
            followers TEXT,
            deleted INTEGER,
            blocked INTEGER,
            followed INTEGER,
            rate_7 REAL,
            rate_30 REAL,
            rate_90 REAL
          )
          SQL
          "CREATE TABLE posts (#{POST_COLUMNS})",
          "CREATE TABLE referenced (#{POST_COLUMNS})",
          <<-SQL,
          CREATE TABLE answers (
            iri TEXT PRIMARY KEY REFERENCES posts(iri),
            included INTEGER,
            failure TEXT CHECK (failure IN ('transient', 'permanent')),
            reason TEXT,
            keep INTEGER,
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
          getter keep : Bool?

          def to_answer : Judgment | Failure
            included, failure = @included, @failure
            if !included.nil? && failure.nil?
              Judgment.new(included: included, reason: reason, keep: keep || false)
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
            referenced = objects.flat_map { |object| [object.in_reply_to?(include_deleted: true), object.quote?(include_deleted: true)] }.compact.uniq!(&.iri)
            (objects + referenced).compact_map(&.attributed_to?(include_deleted: true)).uniq!(&.iri).each do |actor|
              serialized_author = Serializers::Author.from(actor, feed.owner_iri, now)
              db.exec(
                "INSERT INTO authors (iri, type, handle, followers, deleted, blocked, followed, rate_7, rate_30, rate_90) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                serialized_author.iri,
                serialized_author.type,
                serialized_author.handle,
                serialized_author.followers,
                serialized_author.deleted,
                serialized_author.blocked,
                serialized_author.followed,
                serialized_author.rate_7,
                serialized_author.rate_30,
                serialized_author.rate_90,
              )
            end
            objects.each { |object| insert_post(db, "posts", object, feed.owner_iri) }
            referenced.each { |object| insert_post(db, "referenced", object, feed.owner_iri) }
          end
        end

        private def insert_post(db, table, object, owner_iri)
          serialized_post = Serializers::Post.from(object, owner_iri)
          db.exec(
            %(INSERT INTO #{table} (iri, type, name, summary, content, "to", "cc", audience, attachments, published, in_reply_to, thread, quote, language, sensitive, hashtags, mentions, labels, author, deleted, blocked, timeline, poll) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)),
            serialized_post.iri,
            serialized_post.type,
            serialized_post.name,
            serialized_post.summary,
            serialized_post.content,
            serialized_post.to.to_json,
            serialized_post.cc.to_json,
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
            serialized_post.labels.to_json,
            serialized_post.author,
            serialized_post.deleted,
            serialized_post.blocked,
            serialized_post.timeline,
            serialized_post.poll.try(&.to_json),
          )
        end

        # Reads the answers, by IRI.
        #
        def read(path : String) : Hash(String, Judgment | Failure)
          DB.open("sqlite3://#{path}") do |db|
            answers = Answer.from_rs(db.query("SELECT iri, included, failure, reason, keep FROM answers"))
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
