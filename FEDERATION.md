# Federation

## Supported federation protocols and standards

- [ActivityPub](https://www.w3.org/TR/activitypub/) (Server-to-Server)
- [WebFinger](https://webfinger.net/)
- [HTTP Signatures](https://datatracker.ietf.org/doc/html/draft-cavage-http-signatures)
- [NodeInfo](https://nodeinfo.diaspora.software/)

## Supported FEPs

- [FEP-67ff: FEDERATION.md](https://codeberg.org/fediverse/fep/src/branch/main/fep/67ff/fep-67ff.md)
- [FEP-044f: Consent-Aware ActivityPub Quoting](https://codeberg.org/fediverse/fep/src/branch/main/fep/044f/fep-044f.md)
- [FEP-2c59: Discovery of a Webfinger address from an ActivityPub actor](https://codeberg.org/fediverse/fep/src/branch/main/fep/2c59/fep-2c59.md)
- [FEP-f1d5: NodeInfo in Fediverse Software](https://codeberg.org/fediverse/fep/src/branch/main/fep/f1d5/fep-f1d5.md)
- [FEP-0151: NodeInfo in Fediverse Software (2025 edition)](https://codeberg.org/fediverse/fep/src/branch/main/fep/0151/fep-0151.md)
- [FEP-9967: Polls](https://codeberg.org/fediverse/fep/src/branch/main/fep/9967/fep-9967.md)

## ActivityPub

### Overview

**Ktistec** is an [ActivityPub](https://www.w3.org/TR/activitypub/) server. It is intended for small numbers of trusted users (everyone is an administrator) who want to own their social media presence. Most instances have only one user/actor. The server implements full ActivityPub Server-to-Server (S2S) federation including inbox/outbox endpoints, delivery, and shared inbox support.

### Actor model

**Supported actor types:**
- `Person` (primary type for users)
- `Application`
- `Group`
- `Organization`
- `Service`

**Profile properties:**
- `preferredUsername` - The actor's username
- `webfinger` - Canonical WebFinger address (FEP-2c59)
- `name` - Display name
- `summary` - Bio/description (HTML supported)
- `icon` - Profile picture
- `image` - Header/banner image
- `attachment` - Profile metadata fields
- `publicKey` - RSA public key for HTTP signature verification

### Discovery

#### WebFinger

WebFinger is available at `/.well-known/webfinger`.

**Accepted resource formats:**
- `acct:username@domain`
- Actor URL (e.g., `https://example.com/actors/username`)

**Returned links:**
- `self` - ActivityPub actor URL with `application/activity+json` type

#### NodeInfo

NodeInfo schema 2.1 is available via `/.well-known/nodeinfo`, conforming to FEP-f1d5 and FEP-0151.

**Endpoints:**
- `/.well-known/nodeinfo` - Discovery document with link to schema 2.1
- `/.well-known/nodeinfo/2.1` - Full NodeInfo document

**Included data:**
- `software` - Name, version, repository, and homepage
- `protocols` - `["activitypub"]`
- `usage.users` - Total users and monthly active users
- `usage.localPosts` - Count of local posts
- `metadata.nodeName` - Server name (per FEP-0151 conventions)

### HTTP request signing

Ktistec uses [HTTP Signatures](https://datatracker.ietf.org/doc/html/draft-cavage-http-signatures) for request authentication.

**Requirements:**
- Signatures are **required** for all POST requests to the inbox
- Signatures are **used** for GET requests when fetching actor data

**Supported algorithms:**
- `rsa-sha256`
- `hs2019`

**Timestamp tolerance:** 5 minutes

**Signed headers typically include:**
- `(request-target)`
- `host`
- `date`
- `digest` (for POST requests with body)

### Content types and representations

**Accepted content types:**
- `application/activity+json`
- `application/ld+json; profile="https://www.w3.org/ns/activitystreams"`

**Emitted content type:**
- `application/ld+json; profile="https://www.w3.org/ns/activitystreams"`

### JSON-LD processing

Ktistec performs **full JSON-LD expansion** using cached contexts. The server caches standard and commonly-encountered third-party contexts (e.g. ActivityStreams, PURL) locally for performance and reliability.

Senders often use terms they never declare. To expand those documents rather than drop the terms, Ktistec merges compatibility definitions into the ActivityStreams context wherever a document references it:

- `Hashtag`
- `sensitive`
- `schema` (`http://schema.org#`), and `PropertyValue` and `value` under it
- `toot` (`http://joinmastodon.org/ns#`), and `featured` under it

### Supported objects

**Primary object types:**
- `Note` - Short-form posts
- `Article` - Long-form content
- `Question` - Polls, per FEP-9967 (with `oneOf`/`anyOf` options and `endTime`)
- `Tombstone` - Deleted content placeholder
- `QuoteAuthorization` - FEP-044f quote consent

**Aliased object types** (treated as Note):
- `Audio`
- `Event`
- `Image`
- `Page`
- `Place`
- `Video`

### Supported activities

**Content activities:**
- `Create` - Create new objects
- `Update` - Edit existing objects
- `Delete` - Remove objects (creates Tombstone)

**Interaction activities:**
- `Like` - Express approval
- `Dislike` - Express disapproval
- `Announce` - Boost/share content

**Relationship activities:**
- `Follow` - Request to follow an actor
- `Accept` - Accept a follow request
- `Reject` - Reject a follow request
- `Undo` - Reverse a previous activity (Follow, Like, Announce, etc.)

**Extension activities:**
- `QuoteRequest` - FEP-044f request to quote a post

### Polls

[FEP-9967](https://codeberg.org/fediverse/fep/src/branch/main/fep/9967/fep-9967.md) is implemented.

The FEP requires that a voter have permission to vote when the poll is not public, but does not define what confers it. In Ktistec, a voter has permission when the poll is public, when the voter is named in the poll's `to`, `cc` or `audience`, or when the poll addresses its author's followers collection and the voter is a confirmed follower.

### Addressing and delivery

**Addressing properties:**
- `to` - Primary recipients
- `cc` - Secondary recipients

**Public addressing:**
- `https://www.w3.org/ns/activitystreams#Public`

**Delivery:**
- Activities are delivered to recipient inboxes
- Shared inbox (`/inbox`) is supported for efficiency
- Failed deliveries are retried with exponential backoff

**Receiving:**
- Inbound activities are accepted at both the shared inbox (`/inbox`) and per-actor inboxes
- Processing is idempotent

### Inbox responses

A POST to an inbox is answered with a status code that tells the sender whether to retry:

- `200 OK` - The activity was accepted, or had already been applied
- `400 Bad Request` - The activity is permanently unacceptable: the body is blank or malformed, the type is unsupported, the signature cannot be verified. Do not retry.
- `502 Bad Gateway` - Processing could not complete because a remote fetch it depended on timed out or failed transiently. Try again.

### Collections

**Standard collections:**
- `followers` - Actors following this actor
- `following` - Actors this actor follows
- `outbox` - Activities published by this actor

**Additional collections:**
- `featured` - Pinned posts
- `replies` - Reply threads

Collections are paginated using `OrderedCollectionPage`.

### Media and attachments

Attachments are supported via the `attachment` property on objects.

**Supported attachment types:**
- Images
- Video
- Audio

An attachment's type is taken from its `mediaType` property. When `mediaType` is absent, it is inferred from the file extension of the attachment's URL. Attachments whose type cannot be determined, or whose URL uses an unsafe scheme, are dropped.

Locally uploaded media files are stored on the instance and served from the `/uploads` path.

### Deletion, updates, and edits

**Updates:**
- Objects
  - `Update(Object)` activities modify existing objects
  - Only `Create` and `Update` may carry an embedded object. On any other activity -- `Announce`, `Like`, `Delete`, `Undo` -- an inline object node is ignored and only its `id` is retained; the object is then taken from cache or dereferenced from that `id`. An activity that merely references an object cannot rewrite it.
  - The updated object replaces the original
  - `updated` timestamp is set
- Actors
  - Inbound: an `Update(Actor)` refreshes the actor's profile and re-verifies its FEP-2c59 WebFinger handle
  - Outbound: a local actor's own profile edits are emitted as an `Update(Actor)`

**Deletion:**
- `Delete` activities remove objects
- A `Tombstone` object is created with the original object's ID
- Remote servers are notified via `Delete` activity delivery
- A `Delete` relayed inside a followed community's (`Group`) `Announce` is applied when the relaying community is in the object's `audience` (and is followed), or the object is already gone at its origin

### Blocks, reporting, and moderation

**Blocking:**
- Users can block remote actors and individual remote objects
- Block activities are not federated

### Known interoperability notes

**Single-user architecture:**
- Ktistec is designed for small numbers of users (typically one)
- While shared inboxes are supported, since each instance typically has one actor, they typically don't provide much benefit

**Compatibility:**
- Tested with Mastodon, PeerTube, Lemmy, PixelFed, and other ActivityPub implementations
- Standard ActivityPub behaviors should work as expected

## Additional documentation

- [Git repository](https://github.com/toddsundsted/ktistec)
