# streamweaver-doc: v1
require 'slim_graph_r/stream_weaver'

use_layout :wide
header1 'Lifecycle states at a glance'
text 'Entry, recovery, review repetition, and completion remain explicit.'

diagram :state, title: 'Publish lifecycle · light', direction: :right do
  state(:draft, 'Draft')
  state(:review, 'In review')
  state(:published, 'Published', emphasis: true)
  initial :draft
  final :published
  transition :draft, :review, on: 'submit', guard: 'complete?', action: 'queue'
  transition :review, :draft, on: 'request changes'
  transition :review, :review, on: 'recheck', action: 'record audit'
  transition :review, :published, on: 'approve'
end

diagram :state, title: 'Connection recovery · dark', direction: :down, theme: :dark, style: :blueprint do
  state(:offline, 'Offline')
  state(:connecting, 'Connecting')
  state(:online, 'Online', emphasis: true)
  initial :offline
  final :online
  transition :offline, :connecting, on: 'connect'
  transition :connecting, :offline, on: 'timeout', action: 'backoff'
  transition :connecting, :connecting, on: 'retry', guard: 'attempts < 3'
  transition :connecting, :online, on: 'handshake'
end
