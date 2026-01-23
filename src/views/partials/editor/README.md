# Editor Presentation

The view templates and partials in this directory are used to render
object editors, taking into account: the state of the object, the type
of the object, user preferences and instructions, and rules about what
editors are available given those inputs.

## Overview

The main entry point is **editor.html.slang** (in the parent
directory). It sets up variables, determines the media type, and
renders the form with either the Trix or Markdown content editor. All
other partials are rendered within this form.

Partials in this directory in render order:

- **\_editor\_errors.html.slang** - Displays validation error messages
  when `has_errors` is true.

- **\_editor\_hidden\_fields.html.slang** - Renders hidden form fields:
  CSRF token, media-type, type, object IRI, in-reply-to, and editor
  params.

- **\_editor\_buttons.html.slang** - Renders editor toggle buttons
  (Rich Text, Markdown, Optional, Include Poll). Determines which
  buttons are displayed, active, and/or disabled. Render state is
  inferred from object state when possible. Query params can override
  object state.

- **\_editor\_language\_visibility.html.slang** - Renders language
  input field and visibility controls.

- **\_editor\_optional\_settings.html.slang** - Renders optional
  settings (title, summary, content warning checkbox, canonical path)
  when `editor=optional` is in the query params.

- **\_editor\_poll.html.slang** - Renders poll options, duration
  dropdown, and multiple choice checkbox when `editor=poll` is in the
  query params.

- **\_editor\_actions.html.slang** - Renders action buttons (Send
  Reply, Publish Post, Create Draft, Update Draft, Update Post, To
  Drafts link).

## Rules

### General

- Editor buttons are only displayed for draft objects.

- A user can only change the **values** of the fields of a published
  object. For example, a user can change the name, summary, or content
  of a published note or poll. The user cannot change the type of a
  published object or the editors rendered for a published object. The
  user cannot change the media type used for the content of a
  published object.

- The editors to render for an object are completely specified by one
  or more "editor" params, provided as a query string in the URL or in
  the body of a form post.

- When an existing draft object is edited (/objects/{id}/edit) if no
  query string is present, the route handler should inspect the
  object, determine the editors to render, assemble a query string,
  and redirect the browser.

### Content

- Content editor buttons (Rich Text and Markdown) are always displayed
  but only enabled when an object's source media type is not set.

- Either the Rich Text or the Markdown content editor button is
  active, but never both. A content editor button can be active but
  disabled, which indicates the media type of the editor but does not
  let the user change the media type.

### Optional

- The optional editor button is displayed for objects that are not
  replies, but only enabled when an object's name, summary, and
  canonical path are all blank.

### Polls

- The poll editor button is displayed for objects that support polls
  and are not replies, but only enabled when an object's poll options
  are all blank.

## Adding a new editor

1. Decide on the name of the new editor.
2. Figure out what objects need to support the new editor and update.
   - src/models/activity\_pub/object.cr
   - spec/models/activity\_pub/object\_spec.cr
   - spec/models/activity\_pub/object/question\_spec.cr
3. Add a partial gated by the presence/absence of the new param in the query.
   - src/views/partials/editor/\_editor\_NEW.html.slang
   - spec/views/partials\_spec.cr
4. Render the partial in editor.html.slang.
   - src/views/partials/editor.html.slang
5. Add a button to show/hide the partial using the param.
   - src/views/partials/editor/\_editor\_buttons.html.slang
   - spec/views/partials\_spec.cr
6. In route handler GET /objects/:id/edit infer query parameter from state of object.
   - src/controllers/objects.cr
   - spec/controllers/objects\_spec.cr
