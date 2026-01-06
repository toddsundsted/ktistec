# ![Ktistec](images/logo.png)
  - [Features](#features)
    - [Text and images](#text-and-images)
    - [Draft posts](#draft-posts)
    - [Threaded replies](#threaded-replies)
    - [Thread Analysis](#thread-analysis)
    - [Translations](#translations)
    - [@-mention and #-hashtag autocomplete](#-mention-and--hashtag-autocomplete)
    - [Custom emoji](#custom-emoji)
    - [Polls](#polls)
    - [Control over comment visibility](#control-over-comment-visibility)
    - [Pretty URLs](#pretty-urls)
    - [Open Graph metadata](#open-graph-metadata)
    - [Followers/following](#followersfollowing)
    - [Content discovery](#content-discovery)
    - [Content filtering](#content-filtering)
    - [Blocking](#blocking)
    - [Bookmarks](#bookmarks)
    - [Pinned posts](#pinned-posts)
    - [RSS feeds](#rss-feeds)
    - [X-Ray Mode](#x-ray-mode)
    - [Metrics](#metrics)
    - [Tasks](#tasks)
    - [Scripts](#scripts)
  - [Theming](#theming)
  - [API](#api)
    - [A Note on ActivityPub](#a-note-on-activitypub)
    - [Publishing an Object](#publishing-an-object)
    - [Sharing an Object (ActivityPub `Announce`)](#sharing-an-object-activitypub-announce)
    - [Liking an Object](#liking-an-object)
    - [Following an Actor](#following-an-actor)
    - [Undoing an Activity](#undoing-an-activity)
    - [Deleting](#deleting)
  - [MCP Support](#mcp-support)
    - [OAuth](#oauth)
  - [Prerequisites](#prerequisites)
  - [Building](#building)
    - [SQLite3 Compatibility](#sqlite3-compatibility)
    - [Running Tests](#running-tests)
  - [Setup, Configuration, and Usage](#setup-configuration-and-usage)
    - [Command Line Options](#command-line-options)
    - [User Settings](#user-settings)
    - [Site Settings](#site-settings)
  - [Contributors](#contributors)
  - [Copyright and License](#copyright-and-license)

**Ktistec** is an [ActivityPub](https://www.w3.org/TR/activitypub/)
server. It is intended for small numbers of trusted users (everyone is
an administrator). It is designed to have few runtime dependencies --
for example, it uses SQLite as its database, instead of PostgreSQL +
Redis + etc. It is licensed under the AGPLv3.

Ktistec powers [Epiktistes](https://epiktistes.com/), my low-volume
home in the Fediverse. If you want to talk to me, I'm
[@toddsundsted@epiktistes.com](https://epiktistes.com/@toddsundsted).

## Features

Ktistec is intended for writing and scripting.

### Text and images

Ktistec supports two editing modes: a rich text editor and a Markdown
editor. Choose your preferred editor in your account settings.

The **rich text editor** provides text formatting options including
*bold*, *italic*, *strikethrough*, *code* (inline and block),
*superscript*/*subscript*, *headers*, *blockquotes* with nested
indentation, and both *bullet* and *numeric* lists.

The rich text editor also supports adding and editing alt text for
images to improve accessibility. Alt text describes images for screen
readers and displays when images fail to load.

<img src="https://raw.githubusercontent.com/toddsundsted/ktistec/main/images/tszn70.png" width=460>

The **Markdown editor** lets you write posts in Markdown syntax.
Ktistec automatically converts Markdown to HTML when you publish. In
addition to CommonMark syntax, Ktistec supports hashtags and mentions.

Ktistec supports inline placement of images, with ActivityPub image
attachments used for compatibility with non-Ktistec servers. Images
support focal point positioning to ensure the most important part of
an image is always visible in thumbnails. Focal point positioning
currently only works with federated attachments. There is no means to
edit an image's focal point locally at this time.

<img src="https://raw.githubusercontent.com/toddsundsted/ktistec/main/images/aecz36.png" width=460>

### Draft posts

Meaningful writing is an iterative process so Ktistec supports draft
posts. Draft posts aren't visible until you publish them. Draft posts,
including draft replies, are automatically saved as you type.

<img src="https://raw.githubusercontent.com/toddsundsted/ktistec/main/images/683hld.png" width=460>

With Ktistec, you can focus on creating without worrying about losing
your work.

### Threaded replies

Threaded replies make it easier to follow discussions with many
posts. To keep the author's first posts together, the author's
self-replies are prioritized in the thread view.

<img src="https://raw.githubusercontent.com/toddsundsted/ktistec/main/images/eaxx1q.png" width=460>

### Thread Analysis

Ktistec can analyze large conversation threads to help you navigate
complex discussions. Thread analysis provides:

- **Key Participants**: Identify the most active contributors
- **Timeline Histogram**: Visualize conversation activity over time
- **Notable Branches**: Discover important sub-conversations within threads

Access thread analysis from the thread view page for any conversation.

### Translations

Integrate Ktistec with a translation service like DeepL or
LibreTranslate (or host your own) and translate posts in other
languages into your own language.

<img src="https://raw.githubusercontent.com/toddsundsted/ktistec/main/images/733yvm.gif" width=460>

See [Configuring Translation](#configuring-translation) for details on
how to set up the integration.

### @-mention and #-hashtag autocomplete

Ktistec automatically converts @-mentions and #-hashtags into links,
and to encourage hands-on-the-keyboard composition, Ktistec supports
autocompletion.

<img src="https://raw.githubusercontent.com/toddsundsted/ktistec/main/images/22aee8.gif" width=460>

### Custom emoji

Ktistec supports viewing custom emoji in posts and on actor
profiles. Custom emoji are federated from remote servers and
automatically rendered when present.

### Polls

Ktistec supports creating, viewing, and voting on polls. Create polls
when composing posts to gather feedback from your followers. When a
post includes a poll, you can see the available options and vote
directly from your timeline. Poll results are updated in real-time as
votes are federated across the network.

### Control over comment visibility

Ktistec promotes healthy dialog and gives you comprehensive control
over content visibility.

<img src="https://raw.githubusercontent.com/toddsundsted/ktistec/main/images/b70e69.png" width=460>

Control which replies to your posts are public and visible to
anonymous users, and which are private.

Mark posts as sensitive using the content warning checkbox in the
editor. Sensitive posts are hidden behind a summary that readers can
click to reveal the content.

Send private messages directly to specific users with proper
visibility controls.

### Pretty URLs

Assign pretty (canonical) URLs to posts, both for SEO and as helpful
mnemonics for users (and yourself).

### Open Graph metadata

Ktistec includes Open Graph metadata support for actor and posts.
When you share a link to your profile or a post on social media
platforms, rich previews with images, titles, and descriptions are
automatically generated. Configure a site image in the site settings
to customize how your instance appears when shared.

### Followers/following

The Fediverse is a distributed social network. You can follow other
users on other servers from your timeline or by searching for them by
name. You can also approve or deny follow requests and manually
refresh an actor's profile directly from their profile page. Ktistec
is also compatible with the "remote follow" protocol used by Mastodon
and other servers.

<img src="https://raw.githubusercontent.com/toddsundsted/ktistec/main/images/88hvqq.png" width=460>

### Content discovery

In addition to following other users, you can follow threads, hashtags
and even mentions. When posts arrive for content you follow, a
notification is added to your notifications. Because running a single
user instance can be lonely, Ktistec also proactively (and gently)
fetches relevant content from other servers.

<img src="https://raw.githubusercontent.com/toddsundsted/ktistec/main/images/d8kf0q.png" width=460>

To make navigation and discovery easier, post details pages now have
labels with links to internal hashtag and mention index pages.

### Content filtering

Content filters prevent undesirable content from appearing in your
timeline and notifications. Filter terms match on the text of a post
(ignoring any markup). Filters support wildcards.

<img src="https://raw.githubusercontent.com/toddsundsted/ktistec/main/images/wzgeti.png" width=460>

### Blocking

Ktistec gives you control over what you see. Blocking authors removes
them and their posts from your timeline, and obscures their handle and
display name. Blocking posts removes individual posts. The user
interface makes it clear when content is unavailable because it has
been deleted or blocked.

<img src="https://raw.githubusercontent.com/toddsundsted/ktistec/main/images/42fwx6.png" width=460>

<img src="https://raw.githubusercontent.com/toddsundsted/ktistec/main/images/epdb39.png" width=460>

### Bookmarks

Save posts for later with bookmarks. Bookmark any post to add it to
your personal bookmarks collection for easy access.

### Pinned posts

Pin important posts to the top of your profile. Pinned posts appear
prominently at the top of your profile page and are also exposed via
the Mastodon "featured posts" collection for compatibility with
Mastodon and other Fediverse servers.

### RSS feeds

Ktistec provides RSS feeds for easy content syndication even without
an account in the Fediverse. RSS feeds are available on the *home
page* and the *account pages*.

### X-Ray Mode

X-Ray Mode is a developer and power-user tool for inspecting
ActivityPub JSON-LD representations of actors, objects, and other
content. Press `Ctrl+Shift+X` on any page to open X-Ray Mode:

- **Cached Version**: View the local JSON-LD representation stored in the Ktistec database
- **Remote Version**: Fetch and view the original JSON-LD representation from the source server
- **Navigation**: Click on any ActivityPub IRI to navigate to that object
- **History**: Use Alt+Left and Alt+Right to navigate through your viewing history

This feature is useful for debugging federation issues, understanding ActivityPub
structures, and verifying how content is stored and represented.

### Metrics

Ktistec tracks metrics about how the instance is performing. Metrics
include inbox and outbox activity, as well as memory usage; and the
machinery is in place to do much more.

<img src="https://raw.githubusercontent.com/toddsundsted/ktistec/main/images/vrxnmg.png" width=460>

### Tasks

View currently running tasks. Tasks, in Ktistec, are background jobs
that deliver content, fetch content, and perform other housekeeping
chores.

<img src="https://raw.githubusercontent.com/toddsundsted/ktistec/main/images/h075mm.png" width=460>

### Scripts

The Ktistec server will periodically and in sequential order run all
**executable** files in the `etc/scripts` directory.

When running scripts, the Ktistec server will set the following
variables in the child process's environment:

* API\_KEY - authenticates the script with the server
* KTISTEC\_HOST - the base URL of the server instance
* KTISTEC\_NAME - the name of the server instance
* USERNAME - the username of the account the script is run as

Output to `STDOUT` and `STDERR` will show up in the Ktistec server
logs.  Output to `STDOUT` will be emitted as severity `INFO` and
output to `STDERR` will be emitted as severity `WARN`.

Scripts can use the [API](#api) to communicate with the Ktistec
server.

## Theming

Ktistec includes built-in theming support that allows for custom theme
creation. The theming system uses a hierarchy of CSS custom
properties and computed fallback values to provide consistent
styling across all elements with a minimum of effort.

Theme authors can customize at multiple levels:

### Level 1 - Base Colors

Define only base colors like `--text-primary`, `--bg-primary`,
`--bg-input`, `--semantic-primary`, etc. Variations are
automatically generated using `color-mix` formulas.

Example:
```css
:root { --semantic-primary: #7277cf; }
```

Result: `--bg-accent-code`, `--anchor-color`, etc. auto-generate using
`--semantic-primary` as the base color.

### Level 2 - Full Control

Define base colors and derived colors. Defined colors are used as
specified. The rest are automatically generated.

Example:
```css
:root {
  --text-primary: #333;
  --text-primary-2: #ff0000;
}
```

Result: `--text-primary-1/-3/-4` auto-generate; `--text-primary-2` is
red.

The full set of CSS custom color properties is found in
[variables.less](src/assets/css/themes/variables.less).

### CSS Classes and Data Attributes

Ktistec exposes rich metadata through CSS classes and data attributes
that you can target in your themes. In the descriptions below, **author**
refers to the original creator of the content, while **actor** refers
to the user performing the activity (e.g., the person who boosted the
post).

#### CSS Classes

##### ActivityPub Object Types
- `object-note`, `object-question`, etc.

##### ActivityPub Actor Types
- `actor-person`, `actor-group`, etc.

##### ActivityPub Activity Types
- `activity-create`, `activity-announce`, `activity-like`

##### Object States
- `is-draft` - Post is a draft
- `is-deleted` - Post or author is deleted
- `is-blocked` - Post or author is blocked
- `is-sensitive` - Post is marked sensitive
- `has-replies` - Post has at least one reply
- `has-media` - Post has media attachments

##### Visibility States
- `visibility-public` - Posted to public timeline
- `visibility-private` - Posted to followers only
- `visibility-direct` - Direct mention

##### Relationship States (when logged in)
- `author-followed-by-me` - You follow the original author
- `actor-followed-by-me` - You follow the announcer/liker

##### Mention States
- `mentions-me` - You are mentioned in this post
- `mentions-only-me` - You are the only actor mentioned

##### Visual States
- `highlighted` - Post is highlighted in the UI
- `depth-0`, `depth-1`, `depth-2`, etc. - Thread depth levels

#### Data Attributes

Data attributes allow targeting specific identities and content identifiers.

##### Author/Actor Identifiers
- `data-author-handle` - Author's full handle (e.g., `@alice@example.com`)
- `data-author-iri` - Author's full IRI (e.g., `https://example.com/actors/alice`)
- `data-actor-handle` - Actor's handle (when different from author, e.g., in boosts)
- `data-actor-iri` - Actor's IRI (when different from author)

##### Content Tags
- `data-followed-hashtags` - Space-separated hashtags you follow that appear in this post
- `data-followed-mentions` - Space-separated mentions you follow that appear in this post
- `data-hashtags` - Up to 10 space-separated hashtags that appear in the post
- `data-mentions` - Up to 10 space-separated mentions that appear in the post

##### Metadata
- `data-object-id` - Database ID of the object

#### Example Selectors

```css
/* Highlight posts from a specific author */
.ui.feed [data-author-handle="@alice@example.com"] {
  border-left: 4px solid purple;
  background: #f5f0ff;
}

/* Style posts about specific topics */
.ui.feed [data-followed-hashtags~="activitypub"] {
  border-left-color: #6b4fbb;
}

/* Followed author shared by followed actor */
.ui.feed .activity-announce.author-followed-by-me.actor-followed-by-me {
  background: linear-gradient(to right, #e8f5e9, #e1f5fe);
  border-left: 4px solid #4caf50;
  border-top: 3px solid #00bcd4;
}

/* Polls from groups */
.ui.feed .object-question.actor-group {
  border-left: 5px solid #ff9800;
}

/* Direct messages from followed authors */
.ui.feed .visibility-direct.author-followed-by-me {
  border: 3px solid #4caf50;
}
```

### Custom Themes

You can create custom themes by adding CSS and/or JavaScript files to
the `public/themes/` directory. These files are automatically added to
every page's HTML `head` element.

#### Creating a Custom Theme

1. Add `.css` and `.js` files to `public/themes/`
2. Use CSS custom properties to override theme variables
3. Restart the server—theme files are discovered at startup

A simple custom theme that supports both light and dark modes:

```css
:root {
  --text-primary: #2c3e50;
  --bg-primary: #ecf0f1;
  --semantic-primary: #e74c3c;
  --anchor-color: #e67e22;
}

@media (prefers-color-scheme: dark) {
  :root {
    --text-primary: #ecf0f1;
    --bg-primary: #2c3e50;
    --semantic-primary: #e74c3c;
    --anchor-color: #f39c12;
  }
}
```

### Light/Dark Mode Support

If themes are properly designed, Ktistec automatically adapts to your
browser's light/dark mode preference.

## API

Given a valid `API_KEY`, scripts and external tools have full access
to the Ktistec server's API.  This allows them to automate actions on
the server such as posting, following, sharing, liking, etc.

The table below contains a list of supported endpoints:

| Method | Path | Notes |
|-|-|-|
| GET    | /actors/:username/inbox     | Retrieves a page of `activities` in your inbox as an ActivityPub collection. |
| GET    | /actors/:username/outbox    | Retrieves a page of `activities` in your outbox as an ActivityPub collection. |
| POST   | /actors/:username/outbox    | Puts an `activity` in your outbox for delivery. |
| GET    | /actors/:username/posts     | Retrieves a page of `objects` you've published. |
| GET    | /actors/:username/drafts    | Retrieves a page of `objects` you've saved as drafts. |
| GET    | /actors/:username/followers | Retrieves a page of `actors` following you. |
| GET    | /actors/:username/following | Retrieves a page of `actors` you're following. |
| GET    | /admin/accounts             | Retrieves all user accounts. |
| GET    | /admin/accounts/new         | Gets a representation of an account. |
| POST   | /admin/accounts             | Creates a new user account. |
| POST   | /settings/actor             | Updates account settings for the authenticated user. |
| GET    | /lookup/activity?iri=:iri   | Looks up the `activity` in the server cache identified by `iri`. |
| GET    | /lookup/actor?iri=:iri      | Looks up the `actor` in the server cache identified by `iri`. |
| GET    | /lookup/object?iri=:iri     | Looks up the `object` in the server cache identified by `iri`. |
| GET    | /sessions                   | Gets a representation of an authentication attempt with unset `username` and `password`. |
| POST   | /sessions                   | Authenticates using the supplied `username` and `password`. |
| DELETE | /sessions                   | Destroys the current session. |

The `/sessions` endpoint is useful when doing script development
outside of the server environment.  The scripts the Ktistec server
runs directly do not need to create their own session -- the supplied
`API_KEY` is sufficient.

### Initial Server Configuration

You can configure a new Ktistec server entirely via the API.

#### Configure Server Settings

First, configure the server host name and site name (no authentication
required):

```bash
curl -s \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"host":"https://your-domain.com","site":"Your Site Name"}' \
  "$KTISTEC_HOST/"
```

#### Create Primary User Account

Next, create the primary user account (again, no authentication
required).

| Name                   | Notes |
|-|-|
| username               | The username for the primary account. |
| password               | The password for the primary account. |
| name                   | Optional. Display name for the account. |
| summary                | Optional. Biography/description for the account. |
| language               | IETF BCP 47 language tag (e.g., "en", "en-US"). |
| timezone               | IANA timezone (e.g., "UTC", "America/New_York"). |
| auto_approve_followers | Optional. When `true`, follow requests are automatically approved. Defaults to `false`. |
| auto_follow_back       | Optional. When `true`, automatically follows back accounts that follow you. Defaults to `false`. |

Example:

```bash
curl -s \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"username":"your_username","password":"YourSecurePassword123@","name":"Your Display Name","summary":"Your summary","language":"en","timezone":"UTC","auto_approve_followers":true,"auto_follow_back":false}' \
  "$KTISTEC_HOST/"
```

### Admin Account Management

#### List All Accounts

Retrieve all user accounts:

```bash
curl -s \
  -X GET \
  -H "Authorization: Bearer $API_KEY" \
  -H "Accept: application/json" \
  "$KTISTEC_HOST/admin/accounts"
```

#### Create New Account

Create a new user account. Supports the same parameters as creating the primary account.

Example:

```bash
curl -s \
  -X POST \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"username":"another_user","password":"AnotherPassword123@","name":"Another User","summary":"Another user account","language":"en","timezone":"UTC","auto_approve_followers":false,"auto_follow_back":true}' \
  "$KTISTEC_HOST/admin/accounts"
```

### Account Settings

#### Update Actor Account Settings

Update account settings for the authenticated user. Requires authentication.

| Name                   | Notes |
|-|-|
| name                   | Optional. Display name for the account. |
| summary                | Optional. Biography/description for the account. |
| language               | Optional. IETF BCP 47 language tag (e.g., "en", "en-US"). |
| timezone               | Optional. IANA timezone (e.g., "UTC", "America/New_York"). |
| password               | Optional. New password for the account. |
| auto_approve_followers | Optional. When `true`, follow requests are automatically approved. When `false`, requests require manual approval. |
| auto_follow_back       | Optional. When `true`, automatically follows back accounts that follow you. |
| image                  | Optional. Full URI of the account's profile image. |
| icon                   | Optional. Full URI of the account's avatar icon. |
| attachments            | Optional. Array of attachment objects. |

Example:

```bash
curl -s \
  -X POST \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"Updated Display Name","summary":"Updated summary","language":"en","timezone":"UTC"}' \
  "$KTISTEC_HOST/settings/actor"
```

### A Note on ActivityPub

At its core, Ktistec is an ActivityPub server and some things about
its API make more sense if you understand a little bit about
ActivityPub.

ActivityPub is a protocol for sending and receiving messages.
Entities called `actors` send and receive `activities`.  `Activities`
represent the various social actions that define interaction on the
Fediverse: posting, sharing and liking posts, following other actors,
etc.

Every `actor` has an `inbox` for receiving `activities` from the
`actors` they follow, and an `outbox` for sending `activities` to the
`actors` that follow them.

A Fediverse "post", "status", "note", "toot", etc. are all names for
an ActivityPub `object`.  ActivityPub `activities` are typically about
`objects`.

ActivityPub `actors`, `activities`, and `objects` are described using
a flavor of JSON known as JSON-LD.  Every `actor`, `activity`, and
`object` is identified by a unique `IRI`.

Ktistec allows a JSON shorthand (described below) to be used when
publishing, which greatly simplifies the development of scripts.

* [ActivityPub W3C Recommendation](https://www.w3.org/TR/activitypub/)

### Publishing an Object

To publish an `object`, `POST` a JSON `activity` to the `outbox`
endpoint (examples assume scripts use `curl`). The JSON `activity` may
include the following fields:

| Name        | Notes |
|-|-|
| type        | Must be "Publish". |
| content     | An HTML formatted string. |
| name        | Optional. A plain text string often displayed as the title of a post. |
| summary     | Optional. A plain text string often used as a summary of a longer post. |
| object      | Optional. The IRI of the `object` being updated (instead of created). |
| in-reply-to | Optional. The IRI of the `object` being replied to. |
| to          | Optional. A comma-separate list of `actors` to address. Specified as IRIs. |
| cc          | Optional. A comma-separate list of `actors` to CC. Specified as IRIs. |
| audience    | Optional. A comma-separate list of `actors` in the audience. Specified as IRIs. |
| visibility  | Optional. Controls post visibility. Values: "public", "private", "direct". |
| sensitive   | Optional. May be `true` or `false`. Marks content as sensitive. |

By default, `cc` includes the publishing `actor`'s followers collection.

Example:

```bash
curl -s \
  -X POST \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"type":"Publish","content":"this is a test","visibility":"public"}' \
  "$KTISTEC_HOST/actors/$USERNAME/outbox"
```

Note: "publishing" an `object` encompasses both creating a new
`object` (an ActivityPub `Create` activity) and updating an existing
`object` (an ActivityPub `Update` activity).

### Sharing an Object (ActivityPub `Announce`)

To share an `object`, `POST` a JSON `activity` to the `outbox`
endpoint. The JSON `activity` may include the following fields:

| Name       | Notes |
|-|-|
| type       | Must be "Announce". |
| object     | The IRI of the `object` being shared. |
| to         | Optional. A comma-separate list of `actors` to address. Specified as IRIs. |
| cc         | Optional. A comma-separate list of `actors` to CC. Specified as IRIs. |
| audience   | Optional. A comma-separate list of `actors` in the audience. Specified as IRIs. |
| visibility | Optional. Controls post visibility. Values: "public", "private", "direct". |

By default, `to` includes the actor to which the `object` is
attributed, and `cc` includes the publishing `actor`'s followers
collection.

Example:

```bash
curl -s \
  -X POST \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"type":"Announce","object":"https://example.com/objects/123","visibility":"public"}' \
  "$KTISTEC_HOST/actors/$USERNAME/outbox"
```

### Liking an Object

To like an `object`, `POST` a JSON `activity` to the `outbox`
endpoint. The JSON `activity` may include the following fields:

| Name       | Notes |
|-|-|
| type       | Must be "Like". |
| object     | The IRI of the `object` being liked. |
| to         | Optional. A comma-separate list of `actors` to address. Specified as IRIs. |
| cc         | Optional. A comma-separate list of `actors` to CC. Specified as IRIs. |
| audience   | Optional. A comma-separate list of `actors` in the audience. Specified as IRIs. |
| visibility | Optional. Controls post visibility. Values: "public", "private", "direct". |

By default, `to` includes the actor to which the `object` is
attributed, and `cc` includes the publishing `actor`'s followers
collection.

Example:

```bash
curl -s \
  -X POST \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"type":"Like","object":"https://example.com/objects/123","visibility":"public"}' \
  "$KTISTEC_HOST/actors/$USERNAME/outbox"
```

### Disliking an Object

To dislike an `object`, `POST` a JSON `activity` to the `outbox`
endpoint. The JSON `activity` may include the following fields:

| Name       | Notes |
|-|-|
| type       | Must be "Dislike". |
| object     | The IRI of the `object` being disliked. |
| to         | Optional. A comma-separate list of `actors` to address. Specified as IRIs. |
| cc         | Optional. A comma-separate list of `actors` to CC. Specified as IRIs. |
| audience   | Optional. A comma-separate list of `actors` in the audience. Specified as IRIs. |
| visibility | Optional. Controls post visibility. Values: "public", "private", "direct". |

By default, `to` includes the actor to which the `object` is
attributed, and `cc` includes the publishing `actor`'s followers
collection.

Example:

```bash
curl -s \
  -X POST \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"type":"Dislike","object":"https://example.com/objects/123","visibility":"public"}' \
  "$KTISTEC_HOST/actors/$USERNAME/outbox"
```

### Following an Actor

To follow an actor, `POST` a JSON `activity` to the `outbox`
endpoint. The JSON `activity` may include the following fields:

| Name   | Notes |
|-|-|
| type   | Must be "Follow". |
| object | The IRI of the `actor` being followed. |

Example:

```bash
curl -s \
  -X POST \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"type":"Follow","object":"https://example.com/actors/alice"}' \
  "$KTISTEC_HOST/actors/$USERNAME/outbox"
```

### Undoing an Activity

You can undo a previously published `activity` by `POST`ing an `Undo`
`activity` to the `outbox` endpoint. The JSON `activity` may include
the following fields:

| Name   | Notes |
|-|-|
| type   | Must be "Undo". |
| object | The IRI of the `activity` being undone. |

Example:

```bash
curl -s \
  -X POST \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"type":"Undo","object":"https://example.com/activities/123"}' \
  "$KTISTEC_HOST/actors/$USERNAME/outbox"
```

### Deleting

You can delete an `actor` or `object` by `POST`ing a `Delete`
`activity` to the `outbox` endpoint. The JSON `activity` may include
the following fields:

| Name   | Notes |
|-|-|
| type   | Must be "Delete". |
| object | The IRI of the `actor` or `object` being deleted. |

Example:

```bash
curl -s \
  -X POST \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"type":"Delete","object":"https://example.com/123"}' \
  "$KTISTEC_HOST/actors/$USERNAME/outbox"
```

## MCP Support

Ktistec provides Model Context Protocol (MCP) server support for
integrating Ktistec with MCP clients. Compatible clients should "just
work" with Ktistec.

**Important:** *Content generation is not currently supported.* There
are technical issues to resolve, but for the most part I currently
prioritize accessibility and analytics use cases.

### OAuth

OAuth2 authentication is required to access the MCP server from a
compatible MCP client.

### Prompts

#### server_info

Demonstrates how to use the MCP server to retrieve and present
detailed information about the Ktistec server.

#### whats_new

Demonstrates how to use the MCP server to retrieve and summarize
recent posts and social activity.

### Resources

#### ktistec://information

Ktistec server instance information including version, collections
supported, statistics, etc.

#### ktistec://users/{id}

User account information for registered users. Returns account details
including username, language, timezone, and related actor information.
Supports a single ID (`ktistec://users/123`).

#### ktistec://actors/{id*}

ActivityPub actor profiles including name, summary, icon, image,
attachments/metadata, and URLs. Supports single ID (`ktistec://actors/123`) or
comma-separated IDs for batch retrieval (`ktistec://actors/123,456,789`).

#### ktistec://objects/{id*}

ActivityPub objects (posts) including name, summary, content,
attachments, and relationships. Supports single ID (`ktistec://objects/123`) or
comma-separated IDs for batch retrieval (`ktistec://objects/123,456,789`).

### Tools

#### count\_collection\_since(name, since)

Count items in ActivityPub collections since a given time. Use this
tool when you want to know if new items have been added in the last
day/week/month.

**Parameters:**
- `name` (string, required) - Name of the collection to count.
- `since` (string, required) - RFC3339 timestamp to count from (e.g., `2024-01-01T00:00:00Z`)

#### paginate\_collection(name, page, size)

Paginate through collections of ActivityPub items. Use this tool when
you want to retrieve the items in a collection.

**Parameters:**
- `name` (string, required) - Name of the collection to paginate
- `page` (integer, optional) - Page number (defaults to 1, minimum 1)
- `size` (integer, optional) - Number of items per page (defaults to 10, minimum 1, maximum 20)

#### read\_resources(uris)

Read one or more resources by URI. Supports all resource types
including templated resources (actors, objects) and static resources
(information, users). Supports batched reads with comma-separated
IDs.

Use this tool as a universal fallback when resources are not supported
by an MCP client.

**Parameters:**
- `uris` (array, required) - Resource URIs to read (e.g., `['ktistec://actors/123,456', 'ktistec://objects/456,789']`)

#### analyze\_thread(object\_id)

Analyze a conversation thread to understand its structure and activity.
Returns key participants, timeline histogram, and notable branches.

**Parameters:**
- `object_id` (integer, required) - Database ID of any object in the thread

#### get\_thread(object\_id, projection, page\_size) or get\_thread(cursor)

Retrieve thread structure, metadata, and summary data for a
conversation thread with pagination support. Supports two modes of
operation: initial query mode and pagination mode.

**Initial query mode** Return summary data and the first page of
objects. If there are more pages, the results include a `cursor`.

**Pagination mode**: Provide only the `cursor` to fetch the next page.
Returns the next page of objects and a new `cursor` if more pages
remain.

**Parameters:**
- `object_id` (integer) - Database ID of any object in the thread
- `projection` (string) - Data fields to include: 'minimal' (IDs and structure only) or 'metadata' (adds authors, timestamps)
- `page_size` (integer) - Number of objects per page
- `cursor` (string) - Opaque pagination cursor

### Supported Collections

  - Standard: `timeline`, `notifications`, `posts`, `drafts`, `likes`, `announces`, `bookmarks`, `pins`, `followers`, `following`
  - Dynamic: `hashtag#<name>` (e.g., `hashtag#technology`), `mention@<name>` (e.g., `mention@euripides`)

### Compatibility

The Ktistec MCP server works well with Claude Desktop and Claude
Code. I have also tested it with Gemini CLI and Cursor. It also works
with open source tools like Goose and Ollama.

## Prerequisites

To run an instance of Ktistec as part of the Fediverse, you'll need a
server with a fixed hostname. In the Fediverse, users are identified
by (and content is addressed to) a username and a hostname.

## Building

You must compile the Ktistec server executable from its source code.
You will need to install a recent release of the [Crystal programming
language](https://crystal-lang.org/install/). Ktistec requires at least
SQLite3 version 3.35.0 (but see notes on [Sqlite3 compatibility](#sqlite3-compatibility)).

To obtain the source code, clone the [Ktistec Github
repo](https://github.com/toddsundsted/ktistec).

If you intend to do *development* on the server, check out the
**main** branch. In addition to Crystal, you'll also need Node.js and
Webpack to build the JS and CSS assets from source.

If you just want to build and run the server, check out the **dist**
branch.

To compile the server:

`$ crystal build src/ktistec/server.cr`

If you're developing on the **main** branch, build the assets next
(skip this step if you're on the **dist** branch--the latest JS and
CSS assets are already built for you):

`$ npm run build`

Run the compiled executable:

`$ LOG_LEVEL=INFO ./server`

The first time the server runs it will run the database migrations
necessary to create the database. This should only take a few seconds,
maximum. When the server is ready to accept connections you will see
something like:

`Ktistec is ready to lead at http://0.0.0.0:3000`

You can now connect to and configure the server.

### SQLite3 Compatibility

The following SQLite3 versions are known to have bugs that cause
problems for Ktistec:

| SQLite Version | Issue |
|--|--|
| 3.39.x | problems with bloom filters and recursive queries [link](https://sqlite.org/forum/forumpost/56de336385) |
| 3.40.x | problems with bloom filters and recursive queries [link](https://sqlite.org/forum/forumpost/56de336385) |

### Running Tests

If you change the code, you should run the tests:

`$ crystal spec`

## Setup, Configuration, and Usage

The server runs on port 3000. If you're planning on running it in
production, you should put Nginx or Apache in front of it. Don't
forget an SSL certificate!

When you run Ktistec for the first time, you'll need to name the
server and create the primary user.

Ktistec needs to know the *host name* of its home on the internet.
The server host name is a part of every users's identity in the
Fediverse. My identity is "toddsundsted@epiktistes.com". The host name
is "epiktistes.com" and other federated servers, and users, know to
send posts and other content to me there.

Give the server a *site name*, too.

<img src="https://raw.githubusercontent.com/toddsundsted/ktistec/main/images/kl3yf6.png" width=640>

After you name the server, you create the primary user account. The
primary user can create additional user accounts via the admin
interface at `/admin/accounts`. All additional users are also
administrators.

At a minimum, you need to specify the user's *username*, *password*,
*language*, and *timezone*. You can use a single character for the
*username* if you want, but you'll need six characters, including
letters, numbers and symbols, for the *password* (but more than six
characters is better). *language* is any valid IETF BCP 47 language
tag (e.g. "en-US" or "en").  *timezone* is any valid IANA time zone
database string (e.g. "America/New_York").

You can select an ActivityPub actor type. "Person" is the
default. Other options are "Application", "Group", "Organization",
and "Service".

*Display name* and *summary* are optional.

<img src="https://raw.githubusercontent.com/toddsundsted/ktistec/main/images/mq4ntx.png" width=640>

Once these steps are done, you're running!

<img src="https://raw.githubusercontent.com/toddsundsted/ktistec/main/images/o0ton2.png" width=640>

### Command Line Options

The Ktistec server supports several command line options:

#### `--full-garbage-collection-on-startup`

**⚠️ WARNING: This operation can take significant time and delete large amounts of data.**

Garbage collection removes old ActivityPub objects that are not
connected to your user through:

- **Attribution**: Objects attributed to you or actors you follow
- **Activities**: Objects referenced by your activities or activities of actors you follow
- **Collections**: Objects in your timeline, notifications, or outbox
- **Content**: Objects with hashtags, mentions, or in threads you follow

Note that garbage collection preserves:

- Complete threads if any object in a thread is preserved
- Objects newer than the configured age limit (default: 365 days)

It also:

- Performs database optimization (VACUUM and PRAGMA optimize) after cleanup
- May take minutes to hours, depending on database size
- Should not be interrupted once started

**Consider backing up your database before using this option!**

### User Settings

Ktistec provides comprehensive user/account settings that you can
access through the web interface. Navigate to the settings page to
configure your settings.

**Available Settings:**

- **Display Name**: Your public display name shown on your profile
- **Summary**: Your biography or profile description
- **Language**: IETF BCP 47 language tag (e.g., "en-US", "de", "ja") used for your posts and UI preferences
- **Timezone**: IANA timezone (e.g., "America/New_York", "UTC") for displaying timestamps and aggregating metrics
- **Password**: When supplied, updates your account password
- **Auto-approve Followers**: When enabled, follow requests are automatically approved without requiring manual review
- **Auto-follow Back**: When enabled, automatically follows back actors that follow you
- **Default Editor**: Choose between the rich text editor or Markdown editor for composing posts
- **Background Image**: Your profile banner/background image
- **Profile Image**: Your profile avatar icon
- **Metadata**: Up to four custom profile metadata fields with name/value pairs

These settings can also be configured via the API (see [Account Settings](#account-settings)
in the API documentation).

### Site Settings

Site settings control server-wide configuration. You can access these
from the settings page.

**Available Settings:**

- **Site Name**: The name of your Ktistec instance
- **Site Image**: An image used for Open Graph metadata when sharing your instance on social media
- **Description**: A customizable description displayed on your home page
- **Footer**: A customizable footer displayed at the bottom of every page
- **Translator Service**: Choose translation service (DeepL or LibreTranslate) if API keys are configured
- **Translator Service URL**: API endpoint for the selected translation service

#### Site Description

Ktistec supports a customizable site description on your home
page.

<img src="https://raw.githubusercontent.com/toddsundsted/ktistec/main/images/6j98as.png" width=640>

Edit your site description using the same rich text editor you use for
authoring posts:

1. Visit Site Settings on the settings page
2. Use the rich text editor to change the site description
3. Press Update

#### Translation

First, ensure you've set your language in Account Settings on
the settings page. Your  language must be a valid [IETF BCP 47
language tag](https://en.wikipedia.org/wiki/IETF_language_tag) like
"en-US" for US English, "de" for German (Deutsch), or "ja" for
Japanese (日本語).

In order to enable translation, you need an *API key* for either
[DeepL](https://www.deepl.com/) or [LibreTranslate](https://libretranslate.com/).
These are the only services Ktistec supports at this time.

Depending on the service you use, you need to set either the
environment variable `DEEPL_API_KEY` or `LIBRETRANSLATE_API_KEY`
to the API key and restart Ktistec.

Once the API key is set correctly, Site Settings on the settings page
will show an input for the translator service API endpoint. Currently,
supported values are:
https://api.deepl.com/v2/translate (for the DeepL paid service) or
https://api-free.deepl.com/v2/translate (for the DeepL free service), or
https://libretranslate.com/translate (for the LibreTranslate paid
service).

<img src="https://raw.githubusercontent.com/toddsundsted/ktistec/main/images/2i73hd.png" width=640>

*If you change the service API or change the service you are using, you
will need to restart Ktistec.*

Posts from properly configured accounts on supported servers, like
Mastodon, include the language the content is written in. On these
posts, Ktistec will display a button to translate the content if the
language differs from your default language.

A few caveats:

* Some ActivityPub servers don't explicitly support language.
* Some users don't correctly set their posts' language.

TL;DR It's a big Fediverse so translation won't always work.

## Contributors

- [Todd Sundsted](https://github.com/toddsundsted) - creator and maintainer

## Copyright and License

Ktistec ActivityPub Server
Copyright (C) 2021, 2022, 2023, 2024, 2025 Todd Sundsted

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public
License along with this program. If not, see
(https://www.gnu.org/licenses/).

### LibreJS Compliance

Ktistec is compliant with GNU LibreJS. All JavaScript bundled with
Ktistec is free software. A complete list of JavaScript and Crystal
dependencies with their licenses is available at `/license` on any
running Ktistec instance.
