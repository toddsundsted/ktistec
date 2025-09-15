label for="visibility" Visibility
.inline.field
  .ui.radio.checkbox
    input#v-public type="radio" name="visibility" value="public" checked="checked"
    label for="v-public" Everyone
.inline.field
  .ui.radio.checkbox
    input#v-private type="radio" name="visibility" value="private"
    label for="v-private" Followers
.inline.field
  .ui.radio.checkbox
    input#v-direct type="radio" name="visibility" value="direct"
    label for="v-direct" Mentions
