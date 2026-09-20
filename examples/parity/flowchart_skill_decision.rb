# frozen_string_literal: true

require 'slim_graph_r'

# Semantic counterpart to Diagram Design's pinned Flowchart skill-decision
# examples. It preserves the same pinned semantic payload for both supported
# presentation profiles.
module ParityFixtures
  module FlowchartSkillDecision
    module_function

    def diagram(theme: :light, style: :editorial)
      profile = style.to_sym
      unless %i[editorial minimal].include?(profile)
        raise ArgumentError, 'Flowchart skill-decision parity fixture supports minimal and full-editorial profiles'
      end

      SlimGraphR.diagram :flowchart,
                         title: 'Should you write this as a skill?',
                         description: 'A decision flow from a new workflow through repetition and cross-project reuse to a manual one-off, CLAUDE.md note, or reusable skill.',
                         theme: theme,
                         style: profile do
        start :new_workflow, 'New workflow'
        step :manual_once, 'Do it manually once'
        decision :repeat, 'Will you repeat it >3 times?'
        finish :one_off, 'One-off', detail: 'keep manual'
        decision :reusable, 'Reusable across projects?'
        finish :claude_note, 'CLAUDE.md note', detail: 'project-scoped'
        finish :write_skill, 'Write a skill', detail: 'reusable + assets', emphasis: true

        flow :new_workflow, :manual_once, :repeat
        edge :repeat, :one_off, 'NO'
        edge :repeat, :reusable, 'YES'
        edge :reusable, :claude_note, 'NO'
        edge :reusable, :write_skill, 'YES'
      end
    end
  end
end
