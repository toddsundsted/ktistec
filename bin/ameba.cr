#!/usr/bin/env crystal

require "ameba"

require "../src/ameba/ktistec/no_direct_factory_calls"
require "../src/ameba/ktistec/no_imperative_factories"
require "../src/ameba/ktistec/no_alternatives_in_specs"
require "../src/ameba/ktistec/no_focused_specs"
require "../src/ameba/ktistec/no_pending_specs"
require "../src/ameba/ktistec/trailing_comma_on_stacked"

# Require ameba cli which starts the inspection.
require "ameba/cli"
