crystal:
  og_title = actor.display_name.presence
  og_description_raw = actor.summary.presence || "#{actor.display_name} on #{Ktistec.settings.site}"
  og_description = Ktistec::Util.render_as_text_and_truncate(og_description_raw, 155)
  og_image = actor.icon.presence || actor.image.presence || Ktistec.settings.image.presence || "#{Ktistec.host}/images/logo.png"
meta property="og:type" content="profile"
meta property="og:title" content=og_title
meta property="og:description" content=og_description
meta property="og:url" content=actor.display_link
meta property="og:image" content=og_image
meta property="og:image:alt" content=actor.display_name
meta property="profile:username" content=actor.username
meta property="og:site_name" content=Ktistec.settings.site
meta name="twitter:card" content="summary"
meta name="twitter:title" content=og_title
meta name="twitter:description" content=og_description
meta name="twitter:image" content=og_image
