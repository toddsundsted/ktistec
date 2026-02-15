input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
input type="hidden" name="media-type" value=media_type
input type="hidden" name="type" value="Publish"
- unless object.new_record?
  input type="hidden" name="object" value=object.iri
- if object.in_reply_to?
  input type="hidden" name="in-reply-to" value=object.in_reply_to_iri
- if object.quote?
  input type="hidden" name="quote" value=object.quote_iri
- selected_editors.each do |editor|
  input type="hidden" name="editor" value=editor
