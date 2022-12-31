# Changelog
All notable changes to this project are documented in this file.

## [Unreleased]
### Added
- Create the starting database from a single dump instead of running each incremental migration.
- Basic support for timeline filters ("?filters=no-shares,no-replies").

## [v2.0.0-7]
### Added
- Merged [relistan](https://github.com/relistan)'s work on Mastodon-compatible user profile metadata. ([#60](https://github.com/toddsundsted/ktistec/pull/60), fixes [#35](https://github.com/toddsundsted/ktistec/issues/35))
- Merged [vrthra](https://github.com/vrthra)'s work adding links to the internal pages of remote actors. ([#58](https://github.com/toddsundsted/ktistec/pull/58))
- Added GitHub CI action. ([ci.yml](https://github.com/toddsundsted/ktistec/actions/workflows/ci.yml))

### Fixed
- Bottom margin of inline forms with more than one button is now correct.
- Posts no longer drop out of threads when edited.
- Fix CI build failure by including all ActivityPub models before rules definition. ([2258a0f5](https://github.com/toddsundsted/ktistec/commit/2258a0f5))
- Tests run correctly when order of tests is randomized.

### Changed
- Section names ("Metrics" and "Settings") added to title of page.
- Internal links hidden from logged out (anonymous) users.

### Removed
- No longer need to explicitly set KEMAL_ENV when running tests.

## [v2.0.0-6]
### Added
- Uniqueness constraint added on remaining ActivityPub `iri` columns.
- New chart with server and memory-related metrics (server starts, heap size, free kilobytes).

### Fixed
- Added a missed audio media type.
- Posts are no longer mislabeled as replies in notifications.
- Fix a memory leak caused by string interpolation in query string construction.
- Fix handling of unsupported ActivityPub types when deserializing received activities.
- Aggregating points for presentation adjusts times into account's timezone.

### Changed
- Refactored JWT generation and session creation.

## [v2.0.0-5]
### Added
- Added stub for `OrderedCollection`.
- Collect data points for server starts.
- Raise an error during bulk assignment if argument type isn't compatible with property type.
- Raise an error during bulk assignment for properties that may not be bulk-assigned.

### Fixed
- Strip whitespace and handle `@`-prefixed actors in search terms. (fixes [#34](https://github.com/toddsundsted/ktistec/issues/34))
- Fix timeline mislabeling caused by conflict between an earlier ActivityPub like and a later announce.
- Don't authenticate HEAD requests if corresponding GET requests are skipped. (partially fixes [#41](https://github.com/toddsundsted/ktistec/issues/41))
- Add all objects attributed to an actor to the actor's timeline.

### Changed
- Refactored the network resolution of actor URLs and handles during search.
- Updated the text on the remote follow page to better explain how to remote follow.
- Blocks of preformatted content and figure captions display more nicely.
- Images display like on Mastodon. (fixes [#53](https://github.com/toddsundsted/ktistec/issues/53))

## [v2.0.0-4]
### Added
- Added utility support for recreating timeline and notifications.
- Merged [winks](https://github.com/winks)' support for handling 303s in searches. (fixes [#43](https://github.com/toddsundsted/ktistec/pull/43))
- Create `Performance` task and collect data about server performance.

### Fixed
- Mentions of other users no longer show up as mentions in notifications. (fixes [#21](https://github.com/toddsundsted/ktistec/issues/21))
- Distinguish between replies and mentions in notifications.
- Add missing indexes on `actor_iri` and `target_iri` on activities table.
- Fix a memory leak caused by string interpolation in query string construction.

### Changed
- Render actor as a panel instead of a card on the home page.
- Don't display the summary unless it's present.

## [v2.0.0-3]
### Added
- Include replies in notifications.
- Document rules evaluation.

## [v2.0.0-2]
### Added
- Add count of posts to nodeinfo.
- Create `Backup` task to automatically backup servers running in production.
- Support changing password from the settings page.
- Support rule evaluation tracing.

### Fixed
- Add missing index on `attributed_to_iri` on objects table.
- Fix bug in search by re-prioritizing MIME type checks.
- Handle `@`-prefixed actors in remote follow.
- Avoid CORS issues during remote follow.
- Fix text selection in posts.

### Changed
- Move rule definitions out of code and into a file.
- Upgrade Turbo.
- Upgrade Stimulus.
- Upgrade Kemal.

### Removed
- No longer use Travis CI.
- Remove Kilt.

## [v2.0.0-1]
### Added
- Add `include_deleted` support.
- Add `include_undone` support.
- Support queries given associations as arguments.
- Add [School](https://github.com/toddsundsted/school) rules engine.
- Add lexer, parser and compiler for a small, simple rules definition language.
- Support audio and video attachments.
- Display server version information.

### Fixed
- Don't fail to transfer because of a single network error.
- Sign requests to fetch / check for a deleted object.
- During remote follow, respond with 404 if actor doesn't exist.
- Remove mailbox restrictions from approve/unapprove post.
- Handle Webfinger requests that use the HTTPS URI scheme.
- Assume the ActivityStreams context applies to empty documents.
- Assume a canonical LitePub context.
- Sign the "Content-Length" header.

### Changed
- Allow `options` as a hash.
- Rework tracking and handling of model changes.
- Refactor timeline and notifications code to use rules engine.
- Refactor inbox and outbox processing to use rules engine.
- Upgrade Kemal. Add Kilt.

### Removed
- Remove the "@" format URL from actor aliases.
- Remove `prefix` parameter from initialize and assign.

[Unreleased]: https://github.com/toddsundsted/ktistec/compare/b3ce035d...main
[v2.0.0-7]: https://github.com/toddsundsted/ktistec/compare/9a05dced...7d189bd0
[v2.0.0-6]: https://github.com/toddsundsted/ktistec/compare/c71f3ad9...a71ebfda
[v2.0.0-5]: https://github.com/toddsundsted/ktistec/compare/fe3e6967...99dca654
[v2.0.0-4]: https://github.com/toddsundsted/ktistec/compare/31f361b7...76f27dbb
[v2.0.0-3]: https://github.com/toddsundsted/ktistec/compare/feb7ee7d...e6abe307
[v2.0.0-2]: https://github.com/toddsundsted/ktistec/compare/0f24645f...b8fc4693
[v2.0.0-1]: https://github.com/toddsundsted/ktistec/compare/a48f5d77...bc67c11c
