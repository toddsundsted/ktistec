- content_for "og_metadata" do
  - unless object.draft?
    crystal:
      og_title = object.name.presence || "Post by #{object.attributed_to?.try(&.handle)}"
      og_description_raw = object.summary.presence || object.content.presence || ""
      og_description = Ktistec::Util.render_as_text_and_truncate(og_description_raw, 155)
      if (attachments = object.attachments)
        if (img = attachments.find(&.image?))
          og_image = img.url
        end
      end
    meta property="og:type" content="article"
    meta property="og:title" content=og_title
    meta property="og:description" content=og_description
    meta property="og:url" content=object.iri
    - if og_image
      meta property="og:image" content=og_image
    - if (published = object.published)
      meta property="article:published_time" content=published.to_rfc3339
    - if (author = object.attributed_to?)
      meta property="article:author" content=author.iri
    meta property="og:site_name" content=Ktistec.settings.site
    meta name="twitter:card" content=(og_image ? "summary_large_image" : "summary")
    meta name="twitter:title" content=og_title
    meta name="twitter:description" content=og_description
    - if og_image
      meta name="twitter:image" content=og_image
section.ui.feed data-controller="icon-load-error"
  == object_partial(env, object, with_detail: true)
