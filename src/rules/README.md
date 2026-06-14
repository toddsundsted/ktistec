# Rules -- Materialized Collection Maintenance

Keeps Ktistec's derived collections -- the timelines and notification feeds --
equal to a SQL query over current state.

## How it works

Each collection is defined by **one membership `SELECT`**: a row belongs to it
if and only if the query selects it. The query *is* the rule. A single generic
algorithm (`Maintainer`) keeps the stored rows (in `relationships`) equal to the
query by SQL set-difference -- insert what's missing, delete what's no longer
selected, reposition where a member moved. It runs per-key when a base fact
changes (`reconcile_for`) and whole-collection as a drift backstop (`reconcile`).
Writes are raw SQL in a `SAVEPOINT`.

Two layers:

- **`view*.cr` + `maintainer.cr` -- the core. Pure SQL; depends only on `db`.**
  A view is just a membership query, a projection from a changed fact to the
  affected keys, and a position. The maintainer never branches on which view it
  runs.
- **`trigger.cr` -- the edge.** The model-aware adapter: it turns a base-fact
  mutation (an activity, a block, a follow) into "reconcile these views" and
  drives real-time push. It is the only part that knows about model classes.

Not everything in `relationships` is a view: `Inbox`/`Outbox` are receive/send
logs, and a few notifications -- `Quote`, `Poll::Expiry` -- are event records.
`Maintainer.bucket` keeps the batch reconcile off them.

## Why types are strings

A view names the types it queries as **string literals**, not by the model class:

```crystal
TYPE = "Relationship::Content::Notification::Like"   # not ...::Like.to_s
```

This is deliberate. These strings are the values stored in `relationships.type`
-- storage identifiers, not really code references. Naming them by the model class
would force each view to `require` that class, which drags in `framework/model`
and the whole model layer, coupling the pure-SQL core to it.

That coupling then breaks things: anything referencing the core -- notably a
**data migration** that drives the maintainer -- would pull the model layer in
transitively. Strings keep the core dependent on `db` alone, so a migration can
drive the maintainer and every file compiles on its own.

The cost -- a class rename no longer updates the string -- is small and accepted: a
stored type can't be renamed without a data migration anyway, and such renames
are rare. And every literal is pinned to its model's `.to_s` in `type_strings_spec.cr`,
so a drifted literal fails loudly -- with a message naming the stale string -- rather
than silently mis-typing rows. **Keep it this way: reference types as strings, and
never `require` a model from a view or the maintainer.**
