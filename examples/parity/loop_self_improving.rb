# frozen_string_literal: true
require 'slim_graph_r'
module ParityFixtures
  module LoopSelfImproving
    module_function
    def diagram(theme: :light, style: :editorial)
      SlimGraphR.diagram(:loop, title: 'The self-improving loop', theme: theme, style: style, direction: :clockwise) do
        hub :memory, 'Shared memory', sublabel: 'one record, every loop'
        station :capture, 'Capture', sublabel: 'signals in / intake'
        station :research, 'Research', sublabel: 'evidence pulled'
        station :decide, 'Decide', sublabel: 'human approves', focal: true
        station :act, 'Act', sublabel: 'work ships'
        station :measure, 'Measure', sublabel: 'outcomes logged'
        station :learn, 'Learn', sublabel: 'playbook updated'
        cycle :capture, :research, :decide, :act, :measure, :learn
        write_back :capture, to: :memory, label: 'SIGNALS'
        write_back :research, to: :memory; write_back :decide, to: :memory; write_back :act, to: :memory, label: 'OUTCOMES'; write_back :measure, to: :memory; write_back :learn, to: :memory
      end
    end
  end
end
