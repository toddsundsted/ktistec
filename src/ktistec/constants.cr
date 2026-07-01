module Ktistec
  module Constants
    PUBLIC = "https://www.w3.org/ns/activitystreams#Public"

    ACCEPT_HEADER = %q|application/activity+json, application/ld+json; profile="https://www.w3.org/ns/activitystreams"|

    CONTENT_TYPE_HEADER = %q|application/ld+json; profile="https://www.w3.org/ns/activitystreams"|

    LANGUAGE_RE = /^[a-zA-Z]{2,3}(-[a-zA-Z0-9]+)*$/

    # XRD document wrapper used by HostMeta and WebFinger. The body is
    # interpolated into the wrapper (e.g. `XRD_ENV % "<Link .../>"`).
    XRD_ENV = <<-XRD
      <?xml version='1.0'?>
      <XRD
        xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'
        xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'>
      %s
      </XRD>
      XRD

    # Maximum number of posts a user can pin to their profile
    MAX_PINNED_POSTS = 5

    # Maximum number of characters in a post
    MAX_POST_CHARACTERS = 5000

    # Maximum number of media attachments per post
    MAX_MEDIA_ATTACHMENTS = 4

    # Maximum number of characters in an attachment description (alt text)
    MAX_ATTACHMENT_CHARACTERS = 1500

    # Maximum number of options in a poll
    MAX_POLL_OPTIONS = 4

    # Maximum number of characters per poll option
    MAX_POLL_OPTION_CHARACTERS = 50

    # Minimum poll expiration time in seconds
    MIN_POLL_EXPIRATION = 5.minutes.total_seconds.to_i

    # Maximum poll expiration time in seconds
    MAX_POLL_EXPIRATION = 30.days.total_seconds.to_i

    # Maximum image upload size in bytes (10 MB)
    IMAGE_SIZE_LIMIT = 10_485_760

    # Authoritative table of supported media types.
    SUPPORTED_MEDIA_TYPES_TABLE = [
      {mime: "image/apng", category: :image, extensions: %w[.apng]},
      {mime: "image/avif", category: :image, extensions: %w[.avif]},
      {mime: "image/bmp", category: :image, extensions: %w[.bmp]},
      {mime: "image/gif", category: :image, extensions: %w[.gif]},
      {mime: "image/jpeg", category: :image, extensions: %w[.jpeg .jpg]},
      {mime: "image/png", category: :image, extensions: %w[.png]},
      {mime: "image/svg+xml", category: :image, extensions: %w[.svg]},
      {mime: "image/webp", category: :image, extensions: %w[.webp]},
      {mime: "image/x-icon", category: :image, extensions: %w[.ico]},
      {mime: "video/mp4", category: :video, extensions: %w[.mp4]},
      {mime: "video/ogg", category: :video, extensions: %w[.ogv]},
      {mime: "video/quicktime", category: :video, extensions: %w[.mov]},
      {mime: "video/webm", category: :video, extensions: %w[.webm]},
      {mime: "video/x-m4v", category: :video, extensions: %w[.m4v]},
      {mime: "audio/flac", category: :audio, extensions: %w[.flac]},
      {mime: "audio/mp4", category: :audio, extensions: %w[.m4a]},
      {mime: "audio/mpeg", category: :audio, extensions: %w[.mp3]},
      {mime: "audio/ogg", category: :audio, extensions: %w[.oga .ogg]},
      {mime: "audio/wav", category: :audio, extensions: %w[.wav]},
      {mime: "audio/webm", category: :audio, extensions: %w[.webm]},
    ]

    SUPPORTED_UPLOAD_EXTENSIONS =
      SUPPORTED_MEDIA_TYPES_TABLE.flat_map { |e| e[:extensions] }.uniq!

    SUPPORTED_IMAGE_TYPES =
      SUPPORTED_MEDIA_TYPES_TABLE.select { |e| e[:category] == :image }.map { |e| e[:mime] }

    SUPPORTED_VIDEO_TYPES =
      SUPPORTED_MEDIA_TYPES_TABLE.select { |e| e[:category] == :video }.map { |e| e[:mime] }

    SUPPORTED_AUDIO_TYPES =
      SUPPORTED_MEDIA_TYPES_TABLE.select { |e| e[:category] == :audio }.map { |e| e[:mime] }

    SUPPORTED_MEDIA_TYPES =
      SUPPORTED_MEDIA_TYPES_TABLE.map { |e| e[:mime] }

    # Maps a lowercase filename extension to its canonical media type.
    SUPPORTED_MEDIA_TYPES_MAP =
      SUPPORTED_MEDIA_TYPES_TABLE.each_with_object({} of String => String) do |e, map|
        e[:extensions].each { |ext| map[ext] ||= e[:mime] }
      end
  end
end
