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
    - [Metrics](#metrics)
    - [Tasks](#tasks)
    - [Scripts](#scripts)
  - [API](#api)
    - [A Note on ActivityPub](#a-note-on-activitypub)
    - [Publishing an Object](#publishing-an-object)
    - [Sharing an Object (ActivityPub `Announce`)](#sharing-an-object-activitypub-announce))
    - [Liking an Object](#liking-an-object)
    - [Following an Actor](#following-an-actor)
    - [Undoing an Activity](#undoing-an-activity)
    - [Deleting](#deleting)
  - [Prerequisites](#prerequisites)
  - [Building](#building)
    - [SQLite3 Compatibility](#sqlite3-compatibility)
    - [Running Tests](#running-tests)
  - [Usage](#usage)
    - [Command Line Options](#command-line-options)
    - [Configuring Translation](#configuring-translation)
  - [Contributors](#contributors)
  - [Copyright and License](#copyright-and-license)

**Ktistec** is an [ActivityPub](https://www.w3.org/TR/activitypub/)
server. It is intended for individual users, not communities of users,
although support for additional users will be added in the future. It
is designed to have few runtime dependencies -- for example, it uses
SQLite as its database, instead of PostgreSQL + Redis + etc. It is
licensed under the AGPLv3.

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
posts. Draft posts aren't visible until you publish them.

<img src="https://raw.githubusercontent.com/toddsundsted/ktistec/main/images/683hld.png" width=460>

### Threaded replies

Threaded replies make it easier to follow discussions with many
posts.

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

Ktistec promotes healthy dialog. Ktistec allows you to control which
replies to your posts are public and visible to anonymous users, and
which are private.

<img src="https://raw.githubusercontent.com/toddsundsted/ktistec/main/images/b70e69.png" width=460>

### Pretty URLs

Assign pretty (canonical) URLs to posts, both for SEO and as helpful
mnemonics for users (and yourself).

### Followers/following

The Fediverse is a distributed social network. You can follow other
users on other servers from your timeline or by searching for them by
name. Ktistec is also compatible with the "remote follow" protocol
used by Mastodon and other servers.

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
them and their posts from your timeline. Blocking posts removes
individual posts.

<img src="https://raw.githubusercontent.com/toddsundsted/ktistec/main/images/42fwx6.png" width=460>

<img src="https://raw.githubusercontent.com/toddsundsted/ktistec/main/images/epdb39.png" width=460>

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
| GET    | /lookup/activity?iri=:iri   | Looks up the `activity` in the server cache identified by `iri`. |
| GET    | /lookup/actor?iri=:iri      | Looks up the `actor` in the server cache identified by `iri`. |
| GET    | /lookup/object?iri=:iri     | Looks up the `object` in the server cache identified by `iri`. |
| GET    | /sessions                   | Gets a representation of an authentication attempt with unset `username` and `password`. |
| POST   | /sessions                   | Attempts authentication using the supplied `username` and `password`. |
| DELETE | /sessions                   | Destroys the current session. |

The `/sessions` endpoint is useful when doing script development
outside of the server environment.  The scripts the Ktistec server
runs directly do not need to create their own session -- the supplied
`API_KEY` is sufficient.

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
| public      | May be `true` or `false`. |

By default, `cc` incldues the publishing `actor`'s followers collection.

Example:

    outbox="$KTISTEC_HOST/actors/$USERNAME/outbox"
    activity="{\"type\":\"Publish\",\"content\":\"this is a test\",\"public\":true}"
    curl -s -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" -X POST -d "$activity" "$outbox"

Note: "publishing" an `object` encompasses both creating a new
`object` (an ActivityPub `Create` activity) and updating an existing
`object` (an ActivityPub `Update` activity).

### Sharing an Object (ActivityPub `Announce`)

To share an `object`, `POST` a JSON `activity` to the `outbox`
endpoint. The JSON `activity` may include the following fields:

| Name   | Notes |
|-|-|
| type   | Must be "Announce". |
| object | The IRI of the `object` being shared. |
| to     | Optional. A comma-separate list of `actors` to address. Specified as IRIs. |
| cc     | Optional. A comma-separate list of `actors` to CC. Specified as IRIs. |
| public | May be `true` or `false`. |

By default, `to` includes the actor to which the `object` is
attributed, and `cc` includes the publishing `actor`'s followers
collection.

Example:

    outbox="$KTISTEC_HOST/actors/$USERNAME/outbox"
    activity="{\"type\":\"Announce\",\"object\":\"https://example.com/objects/123\",\"public\":true}"
    curl -s -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" -X POST -d "$activity" "$outbox"

### Liking an Object

To like an `object`, `POST` a JSON `activity` to the `outbox`
endpoint. The JSON `activity` may include the following fields:

| Name   | Notes |
|-|-|
| type   | Must be "Like". |
| object | The IRI of the `object` being liked. |
| to     | Optional. A comma-separate list of `actors` to address. Specified as IRIs. |
| cc     | Optional. A comma-separate list of `actors` to CC. Specified as IRIs. |
| public | May be `true` or `false`. |

By default, `to` includes the actor to which the `object` is
attributed, and `cc` includes the publishing `actor`'s followers
collection.

Example:

    outbox="$KTISTEC_HOST/actors/$USERNAME/outbox"
    activity="{\"type\":\"Like\",\"object\":\"https://example.com/objects/123\",\"public\":true}"
    curl -s -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" -X POST -d "$activity" "$outbox"

### Following an Actor

To follow an actor, `POST` a JSON `activity` to the `outbox`
endpoint. The JSON `activity` may include the following fields:

| Name   | Notes |
|-|-|
| type   | Must be "Follow". |
| object | The IRI of the `actor` being followed. |

Example:

    outbox="$KTISTEC_HOST/actors/$USERNAME/outbox"
    activity="{\"type\":\"Follow\",\"object\":\"https://example.com/actors/alice\"}"
    curl -s -H "Authorization Bearer $API_KEY" -H "Content-Type: application/json" -X POST -d "$activity" "$outbox"

### Undoing an Activity

You can undo a previously published `activity` by `POST`ing an `Undo`
`activity` to the `outbox` endpoint. The JSON `activity` may include
the following fields:

| Name   | Notes |
|-|-|
| type   | Must be "Undo". |
| object | The IRI of the `activity` being undone. |

Example:

    outbox="$KTISTEC_HOST/actors/$USERNAME/outbox"
    activity="{\"type\":\"Undo\",\"object\":\"https://example.com/activities/123\"}"
    curl -s -H "Authorization Bearer $API_KEY" -H "Content-Type: application/json" -X POST -d "$activity" "$outbox"

### Deleting

You can delete an `actor` or `object` by `POST`ing a `Delete`
`activity` to the `outbox` endpoint. The JSON `activity` may include
the following fields:

| Name   | Notes |
|-|-|
| type   | Must be "Delete". |
| object | The IRI of the `actor` or `object` being deleted. |

Example:

    outbox="$KTISTEC_HOST/actors/$USERNAME/outbox"
    activity="{\"type\":\"Delete\",\"object\":\"https://example.com/123\"}"
    curl -s -H "Authorization Bearer $API_KEY" -H "Content-Type: application/json" -X POST -d "$activity" "$outbox"

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

## Usage

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

After you name the server, you create the primary user. Ktistec
currently supports only one user. This is intentional -- one of
Ktistec's design goals is to promote a more fully distributed
Fediverse.

At a minimum, you need to specify the user's *username*, *password*,
*language*, and *timezone*. You can use a single character for the
*username* if you want, but you'll need six characters, including
letters, numbers and symbols, for the *password* (but more than six
characters is better). *language* is any valid IETF BCP 47 language
tag (e.g. "en-US" or "en").  *timezone* is any valid IANA time zone
database string (e.g. "America/New_York").

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

### Configuring Translation

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
