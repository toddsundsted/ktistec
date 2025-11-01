# ![Ktistec](public/logo.png)
  - [Features](#features)
    - [Text and images](#text-and-images)
    - [Draft posts](#draft-posts)
    - [Threaded replies](#threaded-replies)
    - [Translations](#translations)
    - [@-mention and #-hashtag autocomplete](#-mention-and--hashtag-autocomplete)
    - [Control over comment visibility](#control-over-comment-visibility)
    - [Pretty URLs](#pretty-urls)
    - [Followers/following](#followersfollowing)
    - [Content discovery](#content-discovery)
    - [Content filtering](#content-filtering)
    - [Blocking](#blocking)
    - [RSS feeds](#rss-feeds)
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
    - [Site Description](#site-description)
    - [Translation](#translation)
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

Text formatting options include *bold*, *italic*, *strikethrough*,
*code* (inline and block), *superscript*/*subscript*, *headers*,
*blockquotes* with nested indentation, and both *bullet* and *numeric*
lists.

<img src="https://raw.githubusercontent.com/toddsundsted/ktistec/main/images/tszn70.png" width=460>

Ktistec supports inline placement of images, with ActivityPub image
attachments used for compatibility with non-Ktistec servers.

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

### RSS feeds

Ktistec provides RSS feeds for easy content syndication even without
an account in the Fediverse. RSS feeds are available on the *home
page* and the *account pages*.

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
creation and automatically adapts to your browser's light/dark mode
preference.

### Built-in Theme Support

Ktistec automatically switches between light and dark themes based on
your browser's color scheme preference. The theming system uses CSS
custom properties to provide consistent styling across all elements.

### Custom Themes

You can create custom themes by adding CSS and/or JavaScript files to
the `public/themes/` directory. These files are automatically added to
every page's HTML `head` element.

#### Creating a Custom Theme

1. Add `.css` and `.js` files to `public/themes/`
2. Use CSS custom properties to override existing theme variables
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

See `src/assets/css/themes/variables.less` for the complete list of
available custom properties.

You can preview how your custom theme affects Ktistec UI elements by
visiting the design system page at `/.design-system`.

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

### Supported Collections

  - Standard: `timeline`, `notifications`, `posts`, `drafts`, `likes`, `announces`, `followers`, `following`
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

### Site Description

Ktistec supports a customizable site description on your home
page.

<img src="https://raw.githubusercontent.com/toddsundsted/ktistec/main/images/6j98as.png" width=640>

Edit your site description using the same rich text editor you use for
authoring posts:

1. Visit Site Settings on the settings page
2. Use the rich text editor to change the site description
3. Press Update

### Translation

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
