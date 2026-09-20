# frozen_string_literal: true

# This is the metadata-declared entry point that StreamWeaver discovers only
# when both gems are installed. Keep it separate from slim_graph_r.rb: the
# renderer itself has no StreamWeaver dependency.
require 'slim_graph_r/stream_weaver'
require 'slim_graph_r/university/provider'

StreamWeaver.register_extension(
  :slim_graph_r,
  course_provider: SlimGraphR::University::Provider.new
)
