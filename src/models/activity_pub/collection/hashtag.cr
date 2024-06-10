require "uri"

require "../collection"

# Methods for working with a hashtag collection.
#
# This class does not itself represent a hashtag collection.
#
class ActivityPub::Collection::Hashtag
  # Finds an existing collection or instantiates a new collection.
  #
  def self.find_or_create(*, name)
    ActivityPub::Collection.find_or_create(iri: "#{Ktistec.host}/tags/#{URI.encode_path_segment(name)}")
  end
end
