- content_for "og_metadata" do
  - unless object.draft?
    crystal:
      og_title = object.name.presence || "Post by #{object.attributed_to?.try(&.handle)}"
      og_description_raw = object.summary.presence || object.content.presence || ""
      og_description = Ktistec::Util.render_as_text_and_truncate(og_description_raw, 155)
      fallback_image = Ktistec.settings.image.presence || "#{Ktistec.host}/images/logo.png"
      image_attachments = [] of ActivityPub::Object::Attachment
      if (attachments = object.attachments)
        image_attachments = attachments.select(&.image?)
      end
    meta property="og:type" content="article"
    meta property="og:title" content=og_title
    meta property="og:description" content=og_description
    meta property="og:url" content=(object.canonical_path ? "#{Ktistec.host}#{object.canonical_path}" : object.iri)
    - if (language = object.language)
      meta property="og:locale" content=language
    - image_attachments.each do |attachment|
      meta property="og:image" content=attachment.url
      meta property="og:image:type" content=attachment.media_type
      - if (alt_text = attachment.caption)
        meta property="og:image:alt" content=alt_text
    - if image_attachments.empty?
      meta property="og:image" content=fallback_image
      meta property="og:image:alt" content=Ktistec.settings.site
    - if (published = object.published)
      meta property="article:published_time" content=published.to_rfc3339
    - if (updated = object.updated)
      meta property="article:modified_time" content=updated.to_rfc3339
    - if (author = object.attributed_to?)
      meta property="article:author" content=author.iri
    - object.hashtags.each do |hashtag|
      meta property="article:tag" content=hashtag.name
    meta property="og:site_name" content=Ktistec.settings.site
    meta name="twitter:card" content="summary"
    meta name="twitter:title" content=og_title
    meta name="twitter:description" content=og_description
    - if image_attachments.empty?
      meta name="twitter:image" content=fallback_image
    - else
      meta name="twitter:image" content=image_attachments.first.url
section.ui.feed data-controller="icon-load-error"
  == object_partial(env, object, with_detail: true)
