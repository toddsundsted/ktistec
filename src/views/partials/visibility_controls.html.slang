crystal:
  _private = env.params.body["visibility"]? == "private" ? "checked" : false
  _direct = env.params.body["visibility"]? == "direct" ? "checked" : false
  _public = !(_private || _direct) ? "checked" : false
label for="visibility" Visibility
.inline.field
  .ui.radio.checkbox
    input#v-public type="radio" name="visibility" value="public" checked=_public
    label for="v-public" Everyone
.inline.field
  .ui.radio.checkbox
    input#v-private type="radio" name="visibility" value="private" checked=_private
    label for="v-private" Followers
.inline.field
  .ui.radio.checkbox
    input#v-direct type="radio" name="visibility" value="direct" checked=_direct
    label for="v-direct" Mentions
