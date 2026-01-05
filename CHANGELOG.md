# Changelog
All notable changes to this project are documented in this file.

## [v3.2.6]
### Added
- Support for editing alt text in the Trix editor. (fixes [#52](https://github.com/toddsundsted/ktistec/issues/52))

### Fixed
- Render fallback icon when actor is down.
- Remove blank `figcaption` elements.
- Emojify display names in notifications.

### Changed
- Color notifications label by type of unread notifications.
- Render lines instead of points for server starts in metrics.

## [v3.2.5]
### Added
- Support for editing posts in Markdown. (fixes [#25](https://github.com/toddsundsted/ktistec/issues/25))
- Support for Open Graph metadata on actors and objects. (fixes [#71](https://github.com/toddsundsted/ktistec/issues/71))
- Support for uploading a site image.
- Internal table of contents page.
- Poll expiry notifications.

## [v3.2.4]
### Added
- Support for viewing and voting on polls. (fixes [#49](https://github.com/toddsundsted/ktistec/issues/49))
- Added tooltip to notifications menu item summarizing new notifications.

### Fixed
- Improved wrapping of actor panel follow/refresh information. (fixes [#130](https://github.com/toddsundsted/ktistec/issues/130))
- Autocomplete now works correctly when adjacent to a Trix attachment.
- Image `title` attributes are now preserved.

### Changed
- Moved avatars to the bottom of the object detail view.

## [v3.2.3]
### Added
- Support for viewing custom emoji in posts and on actor profiles.
- Actor type (Person, Group, etc.) overlay badges on actor panels.
- Colored fallback avatars for actors without icons.
- Support for robots.txt.

### Fixed
- Federation with Lemmy and other servers that support FEP-1b12.
  - Shared inbox support for local actors.
  - Serialization of undone activities includes the original activity.
  - Activities "Like" and "Dislike" are not recursive.
- Notify only once for an object's first received activity.

### Changed
- Accumulate metrics by hour for finer granularity.
- Clean up presentation of public followers/following pages.

## [v3.2.2]
### Added
- Support for pinned posts and the Mastodon "featured posts" collection.
- X-Ray Mode for viewing and navigating JSON-LD resource (actor, object, etc.) representations.
- Back links on thread pages for easier navigation. (fixes [#1](https://github.com/toddsundsted/ktistec/issues/1))
- License page for LibreJS compliance. (fixes [#127](https://github.com/toddsundsted/ktistec/issues/127))
- Highlighting of recently fetched hashtagged posts.

### Changed
- Improved presentation of audio and video media.
- Refactored theming/styling implementation.

## [v3.2.1]
### Added
- Support for bookmarking posts.

### Fixed
- Invalidate user's sessions after changing password.
- Ignore supplied languages that don't conform to expected format.

### Changed
- Upgrade Kemal.

## [v3.2.0]
### Added
- Thread analysis displaying key participants, timeline histogram, and notable branches.
- New MCP tools: `analyze_thread` and `get_thread`.
- Focal point rendering support for image attachments.

### Fixed
- Regression in object visibility affecting replies to threads.

### Changed
- Enhanced MCP tool details for likes, dislikes, and announces.
- Improved cookie security.

## [v3.1.3]
### Added
- Add admin page for managing OAuth access tokens.
- Add support for auto-approve followers. (fixes [#26](https://github.com/toddsundsted/ktistec/issues/26))
- Add support for auto-follow back.

### Fixed
- Prevent triggering actor refresh when user is anonymous.

### Changed
- Replace "lightgallery" dependency with custom image viewer.
- Set OAuth access token expiry to 30 days (previously expired after 24 hours).
- Refactor inbox and outbox processing into dedicated processor services.

## [v3.1.2]
### Added
- Support for the `Dislike` activity.
- Support for the `audience` property on activities and objects.
- Support for delivery to shared inboxes.
- Support for full-width hash signs in hashtags.

### Fixed
- Strip HTML from object summaries rather than escaping it.
- Properly unwrap Lemmy `Announce` activities.

### Changed
- Clean up authorization in actors, activities, objects, relationships, filters, and uploads controllers.
- Destroy discarded drafts instead of deleting them.
- Move inbox and outbox routes into their own controllers.

## [v3.1.1]
### Added
- Auto-link URLs in posts. (fixes [#24](https://github.com/toddsundsted/ktistec/issues/24))
- Support searching by actor username. (fixes [#102](https://github.com/toddsundsted/ktistec/issues/102))
- Support hourly granularity in metrics charts.

### Fixed
- Mark actor as down if refresh fails.
- Remove draft posts from the `everything` collection.
- Ignore charts with no points in the date range.
- Ensure `HTTP::Client` instances are closed.

## [v3.1.0]
This is the first release after merging the `main_3.x` branch. The
merge included the following previously unreleased changes:

### Added
- Add a small banner to highlight "offline" status.
- Support YAML MCP prompts and hot-reloading.

## [v3.0.0]
### Added
- Add OAuth 2.1 authentication for use with 3rd-party tools.
  - Cleanup task for removing expired access tokens and old clients.
  - Admin page for creating/managing OAuth clients.
- Add Model Context Protocol (MCP) server functionality.
  - Resource support for ActivityPub actors and objects, as well as
    registered users and server information.
  - Tool support for counting and paginating collections (timeline,
    likes, announces, etc.).
  - Prompt support demonstrating "What's new?" functionality.
  - OAuth2-authenticated access for secure integration.

## [v2.4.16]
### Changed
- Reorganize the admin menu.

## [v2.4.15]
### Added
- Add support for multiple user accounts.

### Fixed
- Hide attachments behind summary. (fixes [#125](https://github.com/toddsundsted/ktistec/issues/125))
- Mark actors as up after refreshing their profile.

## [v2.4.14]
### Added
- Add design system page for previewing UI elements.
- Support custom themes with automatic light/dark mode switching.
- Add autosave functionality for new posts, draft posts, and replies.

### Changed
- Add external link indicators.

## [v2.4.13]
### Added
- Support RSS feeds on the home page and account pages. (fixes [#14](https://github.com/toddsundsted/ktistec/issues/14))
- Hide sensitive content, spoilers, etc. with content warnings.
- Support direct messages with proper visibility controls.

### Changed
- Switch from calendar-based periods to duration-based periods in charts.

### Fixed
- Track and federate object updates.
- Fix object visibility bugs in object replies and threads.

## [v2.4.12]
### Added
- Add follow request status to the actor panel.
- Compute and cache monthly active accounts.

### Changed
- (Internal) Only consider properties with changed values as "changed".
- (Internal) Only deserialize embedded ActivityPub objects if hosts match.

### Fixed
- Remove line breaks in Turbo Stream output.

### Other
- Many excellent mobile enhancements. (thanks [@JayVii](https://social.jayvii.de/@jayvii))

## [v2.4.11]
### Added
- Support a "site description" on the unauthenticated home page.
- Support autofocus on onboarding and authentication forms.
- Add `trix_editor` view helper.

### Changed
- Remove accounts from unauthenticated home page.
- Persist timeline filters in session.

### Fixed
- Work around bug in `at_beginning_of_week`. (see [crystal-lang/crystal#16112](https://github.com/crystal-lang/crystal/issues/16112))
- Exclude abstract classes from `all_types` output. (fixes [#104](https://github.com/toddsundsted/ktistec/issues/104))

### Other
- Disable streaming updates on pages other than the first. (fixes [#118](https://github.com/toddsundsted/ktistec/issues/118))
- Pin Crystal version at 1.16.3 in Docker build. (see [libxml_ext#1](https://github.com/toddsundsted/libxml_ext/issues/1))

## [v2.4.10]
### Added
- Support manually refreshing actor information. (fixes [#112](https://github.com/toddsundsted/ktistec/issues/112))
- Add link to log level settings to the navigation bar.

### Fixed
- Allow source links to be dragged to the address bar. (fixes [#109](https://github.com/toddsundsted/ktistec/issues/109))
- Fix missing reply/mention notifications for non-create activities.
- Ensure the network is up before attempting to refresh a page.

### Changed
- Block actor handle and display name when actor or post is blocked.
- Gracefully shut down the server.

## [v2.4.9]
### Fixed
- Don't reset `next_attempt_at` in tasks when server restarts.
- Fix incorrect syntax for inline tags in Slang templates.

## [v2.4.8]
### Added
- Send "User-Agent" header on outbound HTTP requests.
- Add accept/reject action buttons to top panel on actor pages.

### Fixed
- Add index on "username" on "actors" table. (fixes regression introduced in [e659e84a](https://github.com/toddsundsted/ktistec/commit/e659e84a))
- Rejection now correctly sets follow relationships as confirmed.
- Correctly handle legacy threads during garbage collection.

### Changed
- Prioritize the author's self-replies in thread view.

### Other
- Temporarily support only Crystal versions 1.16.3 and below.

Note: Crystal version 1.17.0 introduced two breaking issues for Ktistec:
- https://github.com/toddsundsted/libxml_ext/issues/1
- https://github.com/crystal-lang/crystal/pull/16055

## [v2.4.7]
### Added
- Option for garbage collection on startup (see README).

### Fixed
- Use single quotes for string literals in SQLite queries.
- Fix `WITH RECURSIVE` queries.
- Fix broken CI workflow.

### Changed
- Present local internal URLs as external URLs in posts.
- Limit pagination size for unauthenticated users.
- Better convey actor/object deleted/blocked status on index pages.
- Improve presentation of inline code and code blocks.
- Clip alt text on thumbnail images.

### Other
- Update cached copy of Lemmy's JSON-LD context.

## [v2.4.6]
### Fixed
- Add missing database query logging.

### Changed
- Improve query performance for hashtags and mentions.
- Make less costly updates to tag statistics.
- Improve anonymous session management.
- Cache the Nodeinfo count of local posts.

### Removed
- Remove support for `X-Auth-Token`.

### Other
- Add timeout values for POST socket operations.

## [v2.4.5]
### Fixed
- Handle @-mentions with hosts in new posts.
- Handle `HEAD` requests for pages with pretty URLs.
- Destroy session after running scripts.

### Changed
- Delete old authenticated sessions.

### Other
- Reductions (~25%) in build time and executable size.

## [v2.4.4]
### Fixed
- Always get the attachments. (fixes [#119](https://github.com/toddsundsted/ktistec/issues/119))
- Don't run scripts until the server has been configured.

### Changed
- Make the editor toolbar sticky.
- Clear the cached translator when the settings change.

## [v2.4.3]
### Added
- Support for setting a default language on each account.
- Support for setting a distinct language on each object when editing.
- Support for translation.

### Changed
- Monitor streams and refresh page when connections close.
- Re-enable Turbo Drive page morphing.
- In gallery, set `alt` text as attachment caption.

### Other
- Automatically build Docker image of tagged release. (see [#115](https://github.com/toddsundsted/ktistec/pull/115))

## [v2.4.2]
### Fixed
- Fix metrics chart line labels.
- Permit `del`, `ins`, and `s` elements in sanitized HTML.
- Only store the `redirect_after_auth_path` on browser navigation.
- Add "content" property to editor JSON error response.
- Use `FileUtils.mv` to move uploaded files. (fixes [#117](https://github.com/toddsundsted/ktistec/issues/117))

## [v2.4.1]
### Fixed
- Handle edge cases and race conditions in script runner.
- Reconnect editor autocomplete support.
- Fix permissions on uploaded files.

## [v2.4.0]
### Added
- Support running scripted automations (see README).
- "Fetch Once" button on hashtag and thread pages. (fixes [#108](https://github.com/toddsundsted/ktistec/issues/108))
- Support navigation to a post's threaded view. (fixes [#108](https://github.com/toddsundsted/ktistec/issues/108))
- Add support for post `name` and `summary`.

### Fixed
- Improve support for operating without JavaScript available/enabled.
- Only enforce CSRF protection on "simple" requests.

### Changed
- Replace use of multi-action controller with `formaction`. (fixes [#101](https://github.com/toddsundsted/ktistec/issues/101))

### Other
- API usability improvements.

## [v2.3.0]
### Added
- Add monitoring for hung tasks.
- Add timeouts for `open` socket operations.

### Fixed
- Ensure subscribers are notified when a fetch task starts running.
- Restrict actor fetching on broken image icons to profiles.

## [v2.2.0]
### Added
- Support streaming updates to the user-interface.

### Fixed
- Always build assets within building container. (see [#107](https://github.com/toddsundsted/ktistec/pull/107))
- Handle arrays of actor profile images.

## [v2.1.0]
### Added
- Add support for more ActivityPub types.

### Changed
- Upgraded dependencies.

## [v2.0.0]
### Added
- Run "PRAGMA optimize" when a connection is closed.

### Fixed
- Disable faulty Bloom filter optimization. (see [#96](https://github.com/toddsundsted/ktistec/issues/96))
- Fix handling of "(create)" and "date" headers in signatures. (see [#103](https://github.com/toddsundsted/ktistec/issues/103))
- Correctly follow a thread with a cached root.

### Changed
- Interrupt fetch tasks when they are asynchronously set as complete.
- Clear the prior backtrace when following a failed fetch task.

## [v2.0.0-11]
### Added
- Allow user to change log level by functional area.
- Redirect user to previous internal page after sign in succeeds.
- Implement remote interaction/authorize interaction. (see [#91](https://github.com/toddsundsted/ktistec/issues/91))

### Fixed
- Handle object updates from Mastodon servers when the signature can't be verified.
- Don't convert text into a hashtag or mention in links and code. (see [#97](https://github.com/toddsundsted/ktistec/issues/97))

## [v2.0.0-10]
### Added
- Automatically fetch followed threads.
- Automatically fetch followed hashtags.
- Add a system page that displays active tasks.
- Include a replies collection on objects.
- Log the query plan on slow queries.
- Add pages for an actor's likes and shares. (see[#88](https://github.com/toddsundsted/ktistec/issues/88))

### Fixed
- Support actor icon load error handling on every timeline.
- Don't attempt to deliver to actors that are consistently down.
- Save objects even if associated hashtags or mentions don't validate.
- Reduce font size of code in posts.

### Changed
- Display only the followed hashtags/mentions in notifications.
- Aggregate past like/share activities and display a summary in notifications.
- Present a single notification for followed hashtags/mentions/threads.

### Other
- Reduced compile size/time.
- Improved query performance and reduced database size.
- Improved performance of specs.

## [v2.0.0-9]
### Added
- Expose the /everything endpoint.
- Support manually fetching posts that are missing from threads.
- Add link to source/origin of post. (fixes [#42](https://github.com/toddsundsted/ktistec/issues/42))
- Render to HTML posts when content is Markdown. Improves compatibility with Peertube.
- In post details, include labels and links to internal hashtag and mention index pages.
- Support following threads, hashtags and mentions.
- Support pragmas using database connection query params.
- Include short summary of object content in notifications page.
- Check the SQLite3 version.
- Support logging of query times.

### Fixed
- Add ellipsis to Mastodon marked-up URLs in content.
- Make content clickable only on listing pages.
- Call `after_save` lifecycle callback when save occurs.
- Fix bug affecting nested objects during JSON-LD expansion.
- Keep the task worker alive in the face of database problems.
- Set application name in webmanifest. (see [#78](https://github.com/toddsundsted/ktistec/pull/78))
- Update Dockerfile to latest Crystal Alpine. (fixes [#79](https://github.com/toddsundsted/ktistec/issues/79))

### Changed
- Log JSON-LD at `debug` severity.

## [v2.0.0-8]
### Added
- Support content filtering.
- New chart with SQLite3 memory usage metric.
- Add `inverse_of` option to `belongs_to` associations. When saving, update associated models.
- Create the starting database from a single dump instead of running each incremental migration.
- Basic support for timeline filters ("?filters=no-shares,no-replies").

### Fixed
- Handle arrays for profile icons. For PeerTube compatibility.

### Changed
- Don't render pagination block if pagination is not required.

### Removed
- Removed dependencies on externally hosted Semantic UI assets. Removed jQuery.

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

## [v2.0.0-1] - 2023-01-24
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

## Footnotes
[v3.2.6]: https://github.com/toddsundsted/ktistec/compare/28674aa8...79e17af6
[v3.2.5]: https://github.com/toddsundsted/ktistec/compare/2e91c174...20946f62
[v3.2.4]: https://github.com/toddsundsted/ktistec/compare/7de86aa4...107553e8
[v3.2.3]: https://github.com/toddsundsted/ktistec/compare/2ab2a727...023fd225
[v3.2.2]: https://github.com/toddsundsted/ktistec/compare/ab57a3c7...74f7666e
[v3.2.1]: https://github.com/toddsundsted/ktistec/compare/9eebb34e...f6d5f376
[v3.2.0]: https://github.com/toddsundsted/ktistec/compare/65e9e57f...9a25965a
[v3.1.3]: https://github.com/toddsundsted/ktistec/compare/c460d486...c06caebe
[v3.1.2]: https://github.com/toddsundsted/ktistec/compare/ebc7405c...65fd47cb
[v3.1.1]: https://github.com/toddsundsted/ktistec/compare/f9dd19ab...cc5f45ef
[v3.0.0]: https://github.com/toddsundsted/ktistec/compare/d7341dd1...2b777537
[v2.4.16]: https://github.com/toddsundsted/ktistec/compare/db29901e...42f1a298
[v2.4.15]: https://github.com/toddsundsted/ktistec/compare/6e5edf44...a2d1f2f1
[v2.4.14]: https://github.com/toddsundsted/ktistec/compare/a77299f7...f22a2091
[v2.4.13]: https://github.com/toddsundsted/ktistec/compare/b2d4459f...249fefa2
[v2.4.12]: https://github.com/toddsundsted/ktistec/compare/2d0e9500...4f0ea229
[v2.4.11]: https://github.com/toddsundsted/ktistec/compare/157d70d1...fe9aab2c
[v2.4.10]: https://github.com/toddsundsted/ktistec/compare/d7341dd1...a99a66e2
[v2.4.9]: https://github.com/toddsundsted/ktistec/compare/9b9e7b1d...198a1578
[v2.4.8]: https://github.com/toddsundsted/ktistec/compare/3bfb77d0...66f99cb2
[v2.4.7]: https://github.com/toddsundsted/ktistec/compare/c8a59be3...0261e9d3
[v2.4.6]: https://github.com/toddsundsted/ktistec/compare/70d67e74...c51a664c
[v2.4.5]: https://github.com/toddsundsted/ktistec/compare/2eb2560a...04aaaba9
[v2.4.4]: https://github.com/toddsundsted/ktistec/compare/730e0b96...f03cea00
[v2.4.3]: https://github.com/toddsundsted/ktistec/compare/e5dd16ee...1bd44b40
[v2.4.2]: https://github.com/toddsundsted/ktistec/compare/d3dbd74a...8b795e1a
[v2.4.1]: https://github.com/toddsundsted/ktistec/compare/6754d1bd...e6ad8966
[v2.4.0]: https://github.com/toddsundsted/ktistec/compare/084754a5...74f65140
[v2.3.0]: https://github.com/toddsundsted/ktistec/compare/576ceeb2...1aab0951
[v2.2.0]: https://github.com/toddsundsted/ktistec/compare/8d68d896...e8fcc772
[v2.1.0]: https://github.com/toddsundsted/ktistec/compare/a74651d9...238dad82
[v2.0.0]: https://github.com/toddsundsted/ktistec/compare/490b8266...735842c4
[v2.0.0-11]: https://github.com/toddsundsted/ktistec/compare/362f6391...a6ea1385
[v2.0.0-10]: https://github.com/toddsundsted/ktistec/compare/0ae0dc26...9c480ed5
[v2.0.0-9]: https://github.com/toddsundsted/ktistec/compare/4d9094fa...a5fc68f0
[v2.0.0-8]: https://github.com/toddsundsted/ktistec/compare/b3ce035d...cde86283
[v2.0.0-7]: https://github.com/toddsundsted/ktistec/compare/9a05dced...7d189bd0
[v2.0.0-6]: https://github.com/toddsundsted/ktistec/compare/c71f3ad9...a71ebfda
[v2.0.0-5]: https://github.com/toddsundsted/ktistec/compare/fe3e6967...99dca654
[v2.0.0-4]: https://github.com/toddsundsted/ktistec/compare/31f361b7...76f27dbb
[v2.0.0-3]: https://github.com/toddsundsted/ktistec/compare/feb7ee7d...e6abe307
[v2.0.0-2]: https://github.com/toddsundsted/ktistec/compare/0f24645f...b8fc4693
[v2.0.0-1]: https://github.com/toddsundsted/ktistec/compare/a48f5d77...bc67c11c
