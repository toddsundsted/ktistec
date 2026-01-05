# Thread Analysis Service Test Data
# Minimal optimized fixture - generated 2025-11-21 13:20:20 UTC
# Actors: 62, Objects: 86

require "../../src/models/activity_pub/actor/person"
require "../../src/models/activity_pub/object/note"

require "../spec_helper/factory"

def init_thread_analysis_service_fixtures
  person_factory(iri: "https://s/u/1").save
  person_factory(iri: "https://s/u/2").save
  person_factory(iri: "https://s/u/3").save
  person_factory(iri: "https://s/u/4").save
  person_factory(iri: "https://s/u/5").save
  person_factory(iri: "https://s/u/6").save
  person_factory(iri: "https://s/u/7").save
  person_factory(iri: "https://s/u/8").save
  person_factory(iri: "https://s/u/9").save
  person_factory(iri: "https://s/u/10").save
  person_factory(iri: "https://s/u/11").save
  person_factory(iri: "https://s/u/12").save
  person_factory(iri: "https://s/u/13").save
  person_factory(iri: "https://s/u/14").save
  person_factory(iri: "https://s/u/15").save
  person_factory(iri: "https://s/u/16").save
  person_factory(iri: "https://s/u/17").save
  person_factory(iri: "https://s/u/18").save
  person_factory(iri: "https://s/u/19").save
  person_factory(iri: "https://s/u/20").save
  person_factory(iri: "https://s/u/21").save
  person_factory(iri: "https://s/u/22").save
  person_factory(iri: "https://s/u/23").save
  person_factory(iri: "https://s/u/24").save
  person_factory(iri: "https://s/u/25").save
  person_factory(iri: "https://s/u/26").save
  person_factory(iri: "https://s/u/27").save
  person_factory(iri: "https://s/u/28").save
  person_factory(iri: "https://s/u/29").save
  person_factory(iri: "https://s/u/30").save
  person_factory(iri: "https://s/u/31").save
  person_factory(iri: "https://s/u/32").save
  person_factory(iri: "https://s/u/33").save
  person_factory(iri: "https://s/u/34").save
  person_factory(iri: "https://s/u/35").save
  person_factory(iri: "https://s/u/36").save
  person_factory(iri: "https://s/u/37").save
  person_factory(iri: "https://s/u/38").save
  person_factory(iri: "https://s/u/39").save
  person_factory(iri: "https://s/u/40").save
  person_factory(iri: "https://s/u/41").save
  person_factory(iri: "https://s/u/42").save
  person_factory(iri: "https://s/u/43").save
  person_factory(iri: "https://s/u/44").save
  person_factory(iri: "https://s/u/45").save
  person_factory(iri: "https://s/u/46").save
  person_factory(iri: "https://s/u/47").save
  person_factory(iri: "https://s/u/48").save
  person_factory(iri: "https://s/u/49").save
  person_factory(iri: "https://s/u/50").save
  person_factory(iri: "https://s/u/51").save
  person_factory(iri: "https://s/u/52").save
  person_factory(iri: "https://s/u/53").save
  person_factory(iri: "https://s/u/54").save
  person_factory(iri: "https://s/u/55").save
  person_factory(iri: "https://s/u/56").save
  person_factory(iri: "https://s/u/57").save
  person_factory(iri: "https://s/u/58").save
  person_factory(iri: "https://s/u/59").save
  person_factory(iri: "https://s/u/60").save
  person_factory(iri: "https://s/u/61").save
  person_factory(iri: "https://s/u/62").save

  note_factory(iri: "https://s/o/1", attributed_to_iri: "https://s/u/1", attributed_to: nil, in_reply_to_iri: nil, thread: "https://s/o/1", published: Time.parse("2025-01-15 10:00:00", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/2", attributed_to_iri: "https://s/u/2", attributed_to: nil, in_reply_to_iri: "https://s/o/1", thread: "https://s/o/1", published: Time.parse("2025-01-15 10:00:00", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/3", attributed_to_iri: "https://s/u/3", attributed_to: nil, in_reply_to_iri: "https://s/o/2", thread: "https://s/o/1", published: Time.parse("2025-01-15 10:15:00", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/4", attributed_to_iri: "https://s/u/4", attributed_to: nil, in_reply_to_iri: "https://s/o/2", thread: "https://s/o/1", published: Time.parse("2025-01-15 11:06:43", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/5", attributed_to_iri: "https://s/u/3", attributed_to: nil, in_reply_to_iri: "https://s/o/3", thread: "https://s/o/1", published: Time.parse("2025-01-15 11:23:41", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/6", attributed_to_iri: "https://s/u/5", attributed_to: nil, in_reply_to_iri: "https://s/o/2", thread: "https://s/o/1", published: Time.parse("2025-01-15 12:17:15", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/7", attributed_to_iri: "https://s/u/6", attributed_to: nil, in_reply_to_iri: "https://s/o/2", thread: "https://s/o/1", published: Time.parse("2025-01-15 13:19:24", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/8", attributed_to_iri: "https://s/u/5", attributed_to: nil, in_reply_to_iri: "https://s/o/4", thread: "https://s/o/1", published: Time.parse("2025-01-15 14:25:07", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/9", attributed_to_iri: "https://s/u/7", attributed_to: nil, in_reply_to_iri: "https://s/o/4", thread: "https://s/o/1", published: Time.parse("2025-01-15 15:20:27", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/10", attributed_to_iri: "https://s/u/6", attributed_to: nil, in_reply_to_iri: "https://s/o/2", thread: "https://s/o/1", published: Time.parse("2025-01-15 16:34:09", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/11", attributed_to_iri: "https://s/u/6", attributed_to: nil, in_reply_to_iri: "https://s/o/2", thread: "https://s/o/1", published: Time.parse("2025-01-15 17:15:40", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/12", attributed_to_iri: "https://s/u/5", attributed_to: nil, in_reply_to_iri: "https://s/o/4", thread: "https://s/o/1", published: Time.parse("2025-01-15 17:33:14", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/13", attributed_to_iri: "https://s/u/8", attributed_to: nil, in_reply_to_iri: "https://s/o/2", thread: "https://s/o/1", published: Time.parse("2025-01-15 18:30:29", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/14", attributed_to_iri: "https://s/u/9", attributed_to: nil, in_reply_to_iri: "https://s/o/1", thread: "https://s/o/1", published: Time.parse("2025-01-15 18:00:00", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/15", attributed_to_iri: "https://s/u/10", attributed_to: nil, in_reply_to_iri: "https://s/o/14", thread: "https://s/o/1", published: Time.parse("2025-01-15 18:15:00", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/16", attributed_to_iri: "https://s/u/11", attributed_to: nil, in_reply_to_iri: "https://s/o/14", thread: "https://s/o/1", published: Time.parse("2025-01-15 19:25:26", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/17", attributed_to_iri: "https://s/u/7", attributed_to: nil, in_reply_to_iri: "https://s/o/16", thread: "https://s/o/1", published: Time.parse("2025-01-15 20:22:47", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/18", attributed_to_iri: "https://s/u/12", attributed_to: nil, in_reply_to_iri: "https://s/o/16", thread: "https://s/o/1", published: Time.parse("2025-01-15 21:06:39", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/19", attributed_to_iri: "https://s/u/4", attributed_to: nil, in_reply_to_iri: "https://s/o/16", thread: "https://s/o/1", published: Time.parse("2025-01-15 21:57:15", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/20", attributed_to_iri: "https://s/u/13", attributed_to: nil, in_reply_to_iri: "https://s/o/16", thread: "https://s/o/1", published: Time.parse("2025-01-15 23:08:44", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/21", attributed_to_iri: "https://s/u/14", attributed_to: nil, in_reply_to_iri: "https://s/o/16", thread: "https://s/o/1", published: Time.parse("2025-01-15 23:31:20", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/22", attributed_to_iri: "https://s/u/1", attributed_to: nil, in_reply_to_iri: "https://s/o/17", thread: "https://s/o/1", published: Time.parse("2025-01-16 00:07:11", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/23", attributed_to_iri: "https://s/u/15", attributed_to: nil, in_reply_to_iri: "https://s/o/19", thread: "https://s/o/1", published: Time.parse("2025-01-16 01:12:10", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/24", attributed_to_iri: "https://s/u/8", attributed_to: nil, in_reply_to_iri: "https://s/o/20", thread: "https://s/o/1", published: Time.parse("2025-01-16 01:52:28", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/25", attributed_to_iri: "https://s/u/16", attributed_to: nil, in_reply_to_iri: "https://s/o/17", thread: "https://s/o/1", published: Time.parse("2025-01-16 02:55:00", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/26", attributed_to_iri: "https://s/u/17", attributed_to: nil, in_reply_to_iri: "https://s/o/17", thread: "https://s/o/1", published: Time.parse("2025-01-16 03:49:26", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/27", attributed_to_iri: "https://s/u/18", attributed_to: nil, in_reply_to_iri: "https://s/o/20", thread: "https://s/o/1", published: Time.parse("2025-01-16 04:13:13", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/28", attributed_to_iri: "https://s/u/19", attributed_to: nil, in_reply_to_iri: "https://s/o/1", thread: "https://s/o/1", published: Time.parse("2025-01-16 04:00:00", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/29", attributed_to_iri: "https://s/u/20", attributed_to: nil, in_reply_to_iri: "https://s/o/28", thread: "https://s/o/1", published: Time.parse("2025-01-16 04:15:00", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/30", attributed_to_iri: "https://s/u/21", attributed_to: nil, in_reply_to_iri: "https://s/o/28", thread: "https://s/o/1", published: Time.parse("2025-01-16 04:32:33", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/31", attributed_to_iri: "https://s/u/22", attributed_to: nil, in_reply_to_iri: "https://s/o/30", thread: "https://s/o/1", published: Time.parse("2025-01-16 04:49:49", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/32", attributed_to_iri: "https://s/u/21", attributed_to: nil, in_reply_to_iri: "https://s/o/30", thread: "https://s/o/1", published: Time.parse("2025-01-16 05:11:56", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/33", attributed_to_iri: "https://s/u/23", attributed_to: nil, in_reply_to_iri: "https://s/o/30", thread: "https://s/o/1", published: Time.parse("2025-01-16 05:55:28", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/34", attributed_to_iri: "https://s/u/24", attributed_to: nil, in_reply_to_iri: "https://s/o/33", thread: "https://s/o/1", published: Time.parse("2025-01-16 06:56:19", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/35", attributed_to_iri: "https://s/u/23", attributed_to: nil, in_reply_to_iri: "https://s/o/28", thread: "https://s/o/1", published: Time.parse("2025-01-16 07:17:55", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/36", attributed_to_iri: "https://s/u/23", attributed_to: nil, in_reply_to_iri: "https://s/o/34", thread: "https://s/o/1", published: Time.parse("2025-01-16 08:14:26", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/37", attributed_to_iri: "https://s/u/21", attributed_to: nil, in_reply_to_iri: "https://s/o/32", thread: "https://s/o/1", published: Time.parse("2025-01-16 09:02:28", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/38", attributed_to_iri: "https://s/u/25", attributed_to: nil, in_reply_to_iri: "https://s/o/35", thread: "https://s/o/1", published: Time.parse("2025-01-16 09:45:47", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/39", attributed_to_iri: "https://s/u/26", attributed_to: nil, in_reply_to_iri: "https://s/o/1", thread: "https://s/o/1", published: Time.parse("2025-01-16 10:00:00", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/40", attributed_to_iri: "https://s/u/27", attributed_to: nil, in_reply_to_iri: "https://s/o/39", thread: "https://s/o/1", published: Time.parse("2025-01-16 10:15:00", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/41", attributed_to_iri: "https://s/u/28", attributed_to: nil, in_reply_to_iri: "https://s/o/39", thread: "https://s/o/1", published: Time.parse("2025-01-16 10:43:50", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/42", attributed_to_iri: "https://s/u/29", attributed_to: nil, in_reply_to_iri: "https://s/o/41", thread: "https://s/o/1", published: Time.parse("2025-01-16 11:10:49", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/43", attributed_to_iri: "https://s/u/30", attributed_to: nil, in_reply_to_iri: "https://s/o/41", thread: "https://s/o/1", published: Time.parse("2025-01-16 11:44:35", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/44", attributed_to_iri: "https://s/u/17", attributed_to: nil, in_reply_to_iri: "https://s/o/41", thread: "https://s/o/1", published: Time.parse("2025-01-16 12:05:41", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/45", attributed_to_iri: "https://s/u/31", attributed_to: nil, in_reply_to_iri: "https://s/o/41", thread: "https://s/o/1", published: Time.parse("2025-01-16 12:39:43", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/46", attributed_to_iri: "https://s/u/32", attributed_to: nil, in_reply_to_iri: "https://s/o/1", thread: "https://s/o/1", published: Time.parse("2025-01-16 15:00:00", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/47", attributed_to_iri: "https://s/u/13", attributed_to: nil, in_reply_to_iri: "https://s/o/46", thread: "https://s/o/1", published: Time.parse("2025-01-16 15:15:00", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/48", attributed_to_iri: "https://s/u/33", attributed_to: nil, in_reply_to_iri: "https://s/o/46", thread: "https://s/o/1", published: Time.parse("2025-01-16 15:48:22", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/49", attributed_to_iri: "https://s/u/34", attributed_to: nil, in_reply_to_iri: "https://s/o/46", thread: "https://s/o/1", published: Time.parse("2025-01-16 16:08:19", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/50", attributed_to_iri: "https://s/u/35", attributed_to: nil, in_reply_to_iri: "https://s/o/46", thread: "https://s/o/1", published: Time.parse("2025-01-16 16:18:33", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/51", attributed_to_iri: "https://s/u/13", attributed_to: nil, in_reply_to_iri: "https://s/o/50", thread: "https://s/o/1", published: Time.parse("2025-01-16 16:59:54", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/52", attributed_to_iri: "https://s/u/36", attributed_to: nil, in_reply_to_iri: "https://s/o/1", thread: "https://s/o/1", published: Time.parse("2025-01-16 19:00:00", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/53", attributed_to_iri: "https://s/u/37", attributed_to: nil, in_reply_to_iri: "https://s/o/52", thread: "https://s/o/1", published: Time.parse("2025-01-16 19:15:00", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/54", attributed_to_iri: "https://s/u/38", attributed_to: nil, in_reply_to_iri: "https://s/o/52", thread: "https://s/o/1", published: Time.parse("2025-01-16 19:25:26", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/55", attributed_to_iri: "https://s/u/39", attributed_to: nil, in_reply_to_iri: "https://s/o/54", thread: "https://s/o/1", published: Time.parse("2025-01-16 19:44:50", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/56", attributed_to_iri: "https://s/u/40", attributed_to: nil, in_reply_to_iri: "https://s/o/54", thread: "https://s/o/1", published: Time.parse("2025-01-16 20:05:47", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/57", attributed_to_iri: "https://s/u/41", attributed_to: nil, in_reply_to_iri: "https://s/o/52", thread: "https://s/o/1", published: Time.parse("2025-01-16 20:41:36", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/58", attributed_to_iri: "https://s/u/9", attributed_to: nil, in_reply_to_iri: "https://s/o/52", thread: "https://s/o/1", published: Time.parse("2025-01-16 21:04:03", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/59", attributed_to_iri: "https://s/u/15", attributed_to: nil, in_reply_to_iri: "https://s/o/54", thread: "https://s/o/1", published: Time.parse("2025-01-16 21:14:28", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/60", attributed_to_iri: "https://s/u/42", attributed_to: nil, in_reply_to_iri: "https://s/o/1", thread: "https://s/o/1", published: Time.parse("2025-01-17 01:00:00", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/61", attributed_to_iri: "https://s/u/43", attributed_to: nil, in_reply_to_iri: "https://s/o/60", thread: "https://s/o/1", published: Time.parse("2025-01-17 01:15:00", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/62", attributed_to_iri: "https://s/u/13", attributed_to: nil, in_reply_to_iri: "https://s/o/60", thread: "https://s/o/1", published: Time.parse("2025-01-17 01:41:00", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/63", attributed_to_iri: "https://s/u/44", attributed_to: nil, in_reply_to_iri: "https://s/o/62", thread: "https://s/o/1", published: Time.parse("2025-01-17 02:13:40", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/64", attributed_to_iri: "https://s/u/45", attributed_to: nil, in_reply_to_iri: "https://s/o/62", thread: "https://s/o/1", published: Time.parse("2025-01-17 02:57:55", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/65", attributed_to_iri: "https://s/u/46", attributed_to: nil, in_reply_to_iri: "https://s/o/1", thread: "https://s/o/1", published: Time.parse("2025-01-17 04:00:00", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/66", attributed_to_iri: "https://s/u/15", attributed_to: nil, in_reply_to_iri: "https://s/o/65", thread: "https://s/o/1", published: Time.parse("2025-01-17 04:15:00", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/67", attributed_to_iri: "https://s/u/47", attributed_to: nil, in_reply_to_iri: "https://s/o/65", thread: "https://s/o/1", published: Time.parse("2025-01-17 04:57:03", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/68", attributed_to_iri: "https://s/u/48", attributed_to: nil, in_reply_to_iri: "https://s/o/65", thread: "https://s/o/1", published: Time.parse("2025-01-17 05:22:15", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/69", attributed_to_iri: "https://s/u/49", attributed_to: nil, in_reply_to_iri: "https://s/o/68", thread: "https://s/o/1", published: Time.parse("2025-01-17 06:03:56", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/70", attributed_to_iri: "https://s/u/49", attributed_to: nil, in_reply_to_iri: "https://s/o/65", thread: "https://s/o/1", published: Time.parse("2025-01-17 06:17:09", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/71", attributed_to_iri: "https://s/u/50", attributed_to: nil, in_reply_to_iri: "https://s/o/69", thread: "https://s/o/1", published: Time.parse("2025-01-17 06:46:41", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/72", attributed_to_iri: "https://s/u/51", attributed_to: nil, in_reply_to_iri: "https://s/o/69", thread: "https://s/o/1", published: Time.parse("2025-01-17 07:23:53", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/73", attributed_to_iri: "https://s/u/52", attributed_to: nil, in_reply_to_iri: "https://s/o/69", thread: "https://s/o/1", published: Time.parse("2025-01-17 08:00:57", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/74", attributed_to_iri: "https://s/u/53", attributed_to: nil, in_reply_to_iri: "https://s/o/1", thread: "https://s/o/1", published: Time.parse("2025-01-17 09:00:00", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/75", attributed_to_iri: "https://s/u/33", attributed_to: nil, in_reply_to_iri: "https://s/o/74", thread: "https://s/o/1", published: Time.parse("2025-01-17 09:15:00", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/76", attributed_to_iri: "https://s/u/8", attributed_to: nil, in_reply_to_iri: "https://s/o/74", thread: "https://s/o/1", published: Time.parse("2025-01-17 09:51:18", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/77", attributed_to_iri: "https://s/u/54", attributed_to: nil, in_reply_to_iri: "https://s/o/74", thread: "https://s/o/1", published: Time.parse("2025-01-17 10:24:55", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/78", attributed_to_iri: "https://s/u/55", attributed_to: nil, in_reply_to_iri: "https://s/o/77", thread: "https://s/o/1", published: Time.parse("2025-01-17 10:44:06", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/79", attributed_to_iri: "https://s/u/56", attributed_to: nil, in_reply_to_iri: "https://s/o/77", thread: "https://s/o/1", published: Time.parse("2025-01-17 11:00:22", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/80", attributed_to_iri: "https://s/u/57", attributed_to: nil, in_reply_to_iri: "https://s/o/74", thread: "https://s/o/1", published: Time.parse("2025-01-17 11:19:54", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/81", attributed_to_iri: "https://s/u/58", attributed_to: nil, in_reply_to_iri: "https://s/o/1", thread: "https://s/o/1", published: Time.parse("2025-01-17 13:00:00", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/82", attributed_to_iri: "https://s/u/1", attributed_to: nil, in_reply_to_iri: "https://s/o/81", thread: "https://s/o/1", published: Time.parse("2025-01-17 13:15:00", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/83", attributed_to_iri: "https://s/u/59", attributed_to: nil, in_reply_to_iri: "https://s/o/81", thread: "https://s/o/1", published: Time.parse("2025-01-17 13:53:54", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/84", attributed_to_iri: "https://s/u/60", attributed_to: nil, in_reply_to_iri: "https://s/o/82", thread: "https://s/o/1", published: Time.parse("2025-01-17 14:29:06", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/85", attributed_to_iri: "https://s/u/61", attributed_to: nil, in_reply_to_iri: "https://s/o/82", thread: "https://s/o/1", published: Time.parse("2025-01-17 15:07:00", "%F %T", Time::Location::UTC), visible: true).save
  note_factory(iri: "https://s/o/86", attributed_to_iri: "https://s/u/62", attributed_to: nil, in_reply_to_iri: "https://s/o/81", thread: "https://s/o/1", published: Time.parse("2025-01-17 15:43:25", "%F %T", Time::Location::UTC), visible: true).save
end
