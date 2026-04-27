module Ktistec
  module Constants
    PUBLIC = "https://www.w3.org/ns/activitystreams#Public"

    ACCEPT_HEADER = %q|application/activity+json, application/ld+json; profile="https://www.w3.org/ns/activitystreams"|

    CONTENT_TYPE_HEADER = %q|application/ld+json; profile="https://www.w3.org/ns/activitystreams"|

    LANGUAGE_RE = /^[a-zA-Z]{2,3}(-[a-zA-Z0-9]+)*$/

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

    SUPPORTED_IMAGE_TYPES = %w[
      image/apng
      image/avif
      image/bmp
      image/gif
      image/jpeg
      image/png
      image/webp
      image/x-icon
    ]

    SUPPORTED_VIDEO_TYPES = %w[
      video/mp4
      video/ogg
      video/quicktime
      video/webm
      video/x-m4v
    ]

    SUPPORTED_AUDIO_TYPES = %w[
      audio/flac
      audio/mp4
      audio/mpeg
      audio/ogg
      audio/wav
      audio/webm
    ]

    SUPPORTED_UPLOAD_EXTENSIONS = %w[
      .apng .avif .bmp .gif .ico .jpeg .jpg .png .webp
      .m4v .mov .mp4 .ogv .webm
      .flac .m4a .mp3 .oga .ogg .wav
    ]
  end
end
