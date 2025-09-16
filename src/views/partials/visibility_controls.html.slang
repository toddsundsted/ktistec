crystal:
  _public = _private = _direct = false
  case visibility(object.attributed_to, object.to, object.cc)
  when "private"
    _private = "checked"
  when "direct"
    _direct = "checked"
  else
    _public = "checked"
  end
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
