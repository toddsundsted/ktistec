# Judges

A judge is an executable in this directory that decides which posts
belong in a feed. The four judges here are working examples.

## Writing a judge

1. Name it. The filename is the judge's name. Use letters, digits,
   `.`, `_`, and `-`.

2. Declare its settings in comments in its first 10 lines, in
   whatever comment syntax its language uses:

   ```
   # ktistec: revision=2
   # ktistec: batch-size=100
   # ktistec: param=length type=integer
   # ktistec: param=exclude type=string required
   ```

   - `revision`: change it when the judge's answers change, so that
     feeds are judged again.
   - `batch-size`: the most posts it is asked about at once (default
     is 1).
   - `param`: a param a feed can set in the UI. `type` is `integer`
     or `string` (the default). `required` makes it required.

3. Read the questions and write the answers. Ktistec runs the judge
   with one argument, the path to a SQLite file:

   | table | columns |
   |---|---|
   | `feed` | the feed's `name`, `description`, and `params` |
   | `stats` | the owner's followed authors' posting rates: `posting_rate_q1`, `posting_rate_median`, `posting_rate_q3` |
   | `authors` | the authors of the posts in `posts` and `referenced`: `iri`, `type`, `handle`, `followers`, `deleted`, `blocked`, `followed`, `rate_7`, `rate_30`, `rate_90` |
   | `posts` | the posts to judge: `iri`, `type`, `name`, `summary`, `content`, `to`, `cc`, `audience`, `attachments`, `published`, `in_reply_to`, `thread`, `quote`, `language`, `sensitive`, `hashtags`, `mentions`, `labels`, `author`, `deleted`, `blocked`, `timeline`, `poll` |
   | `referenced` | the posts that posts in `posts` reply to or quote, with the same columns as `posts` |

   It also has two empty tables for the judge to write to: `answers`
   (`iri`, `included`, `failure`, `reason`, `keep`) and `unavailable`
   (`reason`, `retry_after`).

   What the values mean:

   - `feed`
     - `params` is the feed's params, as JSON.
   - `stats`
     - `posting_rate_q1`, `posting_rate_median`, and `posting_rate_q3`
       are the quartiles of the posting rates, in posts per day over
       the last 90 days, of the authors the owner follows who posted in
       that time, or null if none did.
   - `authors`
     - `followers` is the IRI of the author's followers collection.
     - `deleted` and `blocked` are 1 if the author is deleted or
       blocked on the owner's server.
     - `followed` is 1 if the owner follows the author.
     - `rate_7`, `rate_30`, and `rate_90` are the author's posts per
       day over the last 7, 30, and 90 days.
   - `posts` and `referenced`
     - `to`, `cc`, and `audience` are JSON arrays of IRIs. A post
       addressed to `https://www.w3.org/ns/activitystreams#Public` is
       public; one addressed to its author's `followers` is for their
       followers.
     - `attachments` is a JSON array of `url`, `media_type`, and
       `caption`.
     - `in_reply_to` is the IRI of the post it replies to.
     - `thread` is the IRI of its thread's first post.
     - `quote` is the IRI of the post it quotes.
     - `hashtags` and `mentions` are JSON arrays of `name` and `href`.
     - `labels` is a JSON array of the names of the owner's private
       labels.
     - `author` is the post's author's `iri` in `authors`.
     - `deleted` and `blocked` are 1 if the post is deleted or blocked
       on the owner's server.
     - `timeline` is how the post reached the owner's timeline
       (`create` or `announce`), or null if it isn't in the timeline. A
       post that was both created and announced into the timeline is
       `create`.
     - `poll` is a JSON object of `options`, `multiple_choice`, and
       `closed_at`, or null if the post isn't a poll.

   Reading the file:

   - Name every column you read and write. Don't read rows by
     position (`SELECT *` with tuple indexes) or insert without a
     column list (`INSERT INTO answers VALUES (...)`). The file's
     `user_version` changes only when a change would break a judge
     that names its columns, like a column that is removed, renamed,
     or given a new meaning.
   - `to` is an SQL keyword, so quote it: `"to"`.
   - Times are UTC text, like `2026-11-01 00:00:00.000`.
   - A post that isn't on the owner's server has no row in
     `referenced`. A post in `posts` that another post in `posts`
     replies to or quotes is in `referenced` too.

   Write one row to `answers` for each post in `posts`: its `iri`, and either
   `included` (1 or 0) or `failure` (`transient` or `permanent`), and
   an optional `reason`:

   ```python
   db.execute(
       "INSERT INTO answers (iri, included, reason) VALUES (?, ?, ?)",
       (iri, int(included), reason),
   )
   ```

   A post with a transient failure is asked about again later. A post
   with a permanent failure is not.

   An exclusion isn't stored, by default, unless the answer sets
   `keep` to 1. Set it when an exclusion would be hard to reconstruct
   later, like one that comes from a model, and leave it out when it's
   trivial. `keep` has no effect on other answers:

   ```python
   db.execute(
       "INSERT INTO answers (iri, included, reason, keep) VALUES (?, 0, ?, 1)",
       (iri, reason),
   )
   ```

4. Handle failure. A post without an answer, a judge that exits
   non-zero, and a judge that runs longer than 5 minutes (it is
   killed) all count as transient failures. A judge that fails three
   batches in a row is paused, for 5 minutes at first and twice as
   long each time after, up to a day.

   A judge that can't work at all (a service it depends on is down,
   for example) can say so and be paused instead:

   ```python
   db.execute(
       "INSERT INTO unavailable (reason, retry_after) VALUES (?, ?)",
       ("service is down", "2026-10-23 18:00:00"),
   )
   ```

   `retry_after` (UTC, optional) shortens the pause.

5. Log. Each line the judge writes to stdout is logged at info, and to
   stderr at warn, tagged with the judge's path.

The judge runs with an empty environment. A judge that needs a secret
reads it from a file.

## Installing a judge

Make it executable:

```
chmod +x etc/judges/polls
```

Ktistec looks for judges at startup and every minute after. An edit to
a judge takes effect within a minute, except a new `revision` or new
params, which take effect only when the server restarts. Editing a
judge (even with `touch`) also resumes it if it is paused.

## Testing a judge

Test a new judge against a copy of your database, where it sees real
posts and can't hurt anything.

1. Copy the database, and delete the copy's pending tasks other than
   feed tasks, so the server doesn't deliver activities or fetch
   anything on your behalf:

   ```
   cp ktistec.db ~/ktistec-copy.db
   sqlite3 ~/ktistec-copy.db "DELETE FROM tasks WHERE type NOT LIKE 'Task::Feed::%'"
   ```

2. Run the server against the copy:

   ```
   KTISTEC_DB=~/ktistec-copy.db ./server
   ```

   Don't post, follow, or reply from the copy.

3. Create a feed, choose the judge, give it its params, and preview
   it. A preview asks the judge about the 100 most recent posts and
   shows up to 20 of the matches. Reload the preview as the answers
   arrive, and watch the log for the judge's output.

4. Publish the feed. Publishing backfills it: the judge is asked about
   every post from the last 30 days, 250 at a time. After that, it is
   asked about each new post as it arrives.

Answers are kept by feed owner, judge, params, and revision. A
preview or backfill doesn't ask about a post the judge already
answered, so after changing what a judge decides, change its
`revision` and restart the server (or change a param) to see the
new answers.
