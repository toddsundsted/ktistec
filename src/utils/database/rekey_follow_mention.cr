module Ktistec
  module Database
    # Re-keys the mention-follow relationships from the handle to the
    # actor identity (the mention tag's `href`).
    #
    module RekeyFollowMention
      extend self

      TYPES = %w[
        Relationship::Content::Follow::Mention
        Relationship::Content::Notification::Follow::Mention
      ]

      # Applies the re-key to both relationship types.
      #
      def run(db)
        TYPES.each do |type|
          drop_unresolvable(db, type)
          rekey_to_dominant_href(db, type)
          dedupe(db, type)
        end
      end

      # Reverses the re-key, re-deriving the dominant handle from the `href`.
      #
      def revert(db)
        TYPES.each do |type|
          db.exec <<-SQL, type
            UPDATE relationships
               SET to_iri = COALESCE((
                 SELECT t.name
                   FROM tags t
                  WHERE t.type = 'Tag::Mention'
                    AND t.href = relationships.to_iri
                    AND t.name IS NOT NULL
               GROUP BY t.name
               ORDER BY count(*) DESC, t.name ASC
                  LIMIT 1
               ), to_iri)
             WHERE type = ?
          SQL
        end
      end

      # Drops rows whose handle resolves to no mentioned `href`.
      #
      private def drop_unresolvable(db, type)
        db.exec <<-SQL, type
          DELETE FROM relationships
           WHERE type = ?
             AND NOT EXISTS (
               SELECT 1
                 FROM tags t
                WHERE t.type = 'Tag::Mention'
                  AND t.name = relationships.to_iri
                  AND t.href IS NOT NULL
             )
        SQL
      end

      # Re-keys `to_iri` from the handle to its dominant mentioned `href`.
      #
      private def rekey_to_dominant_href(db, type)
        db.exec <<-SQL, type
          UPDATE relationships
             SET to_iri = (
               SELECT t.href
                 FROM tags t
                WHERE t.type = 'Tag::Mention'
                  AND t.name = relationships.to_iri
                  AND t.href IS NOT NULL
             GROUP BY t.href
             ORDER BY count(*) DESC, t.href ASC
                LIMIT 1
             )
           WHERE type = ?
        SQL
      end

      # Collapses rows that now share `from_iri`/`to_iri`, keeping the
      # earliest (lowest `id`).
      #
      private def dedupe(db, type)
        db.exec <<-SQL, type, type
          DELETE FROM relationships
           WHERE type = ?
             AND id NOT IN (
               SELECT MIN(id)
                 FROM relationships
                WHERE type = ?
             GROUP BY from_iri, to_iri
             )
        SQL
      end
    end
  end
end
