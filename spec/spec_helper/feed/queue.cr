require "../../../src/services/feed/queue"

# Caps the judge queue at sizes a spec can fill.
#
Feed::Queue.backfill_cap = 2
Feed::Queue.live_cap = 3
