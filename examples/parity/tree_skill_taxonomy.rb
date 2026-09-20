# frozen_string_literal: true
require 'slim_graph_r'

module ParityFixtures
  module TreeSkillTaxonomy
    module_function
    def diagram(theme: :light, style: :editorial)
      raise ArgumentError, 'Tree skill-taxonomy parity fixture supports only the full-editorial profile' unless style.to_sym == :editorial
      SlimGraphR.diagram :tree, title: 'Claude Code skill taxonomy', theme: theme, style: style do
        root :skills, 'Skills', focal: true do
          child :design, 'Design', detail: 'ui · visual · ux' do
            child :polish, 'polish', detail: 'align · space · rhythm'
            child :critique, 'critique', detail: 'hierarchy · density'
          end
          child :engineering, 'Engineering', detail: 'ship · review · test' do
            child :review, 'review', detail: 'pre-land diff · sql'
            child :ship, 'ship', detail: 'merge · deploy · verify'
          end
          child :research, 'Research', detail: 'investigate · analyze' do
            child :investigate, 'investigate', detail: 'root cause · evidence'
          end
        end
      end
    end
  end
end
