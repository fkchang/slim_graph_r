# frozen_string_literal: true
require 'slim_graph_r'

SlimGraphR.diagram(:loop, title: 'Self-improving loop · 自己改善', direction: :clockwise) do
  hub :memory, 'Shared memory', sublabel: 'one record, every loop'
  station :capture, 'Capture', sublabel: 'signals in'
  station :research, 'Research', sublabel: 'evidence pulled'
  station :decide, 'Decide', sublabel: 'human approves', focal: true
  station :act, 'Act', sublabel: 'work ships'
  station :measure, 'Measure', sublabel: 'outcomes logged'
  cycle :capture, :research, :decide, :act, :measure
  write_back :capture, to: :memory, label: 'SIGNALS'
  write_back [:research, :decide, :measure], to: :memory
  write_back :act, to: :memory, label: 'OUTCOMES'
end
