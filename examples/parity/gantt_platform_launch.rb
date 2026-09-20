# frozen_string_literal: true

require 'slim_graph_r'

module ParityFixtures
  module GanttPlatformLaunch
    module_function

    # The pinned source gives W1-W12 across April-June without a year. This
    # explicit Monday anchor preserves those seven-day relative intervals.
    def diagram(theme: :light, style: :editorial)
      SlimGraphR.diagram :gantt, title: 'Q2 product launch · 12-week plan',
                         description: 'A twelve-week product launch from market research and interviews through design review, development, beta testing, and launch.', theme: theme, style: style do
        phase :discovery, 'Discovery' do
          task :market_research, 'Market research', start: '2026-04-06', finish: '2026-04-20'
          task :user_interviews, 'User interviews', start: '2026-04-13', finish: '2026-04-27'
        end
        phase :design, 'Design' do
          task :wireframes, 'Wireframes', start: '2026-04-27', finish: '2026-05-11'
          task :prototype, 'Prototype', start: '2026-05-04', finish: '2026-05-25'
          task :design_review, 'Design review', start: '2026-05-25', finish: '2026-06-01', focal: true
        end
        phase :launch, 'Launch' do
          task :development, 'Development', start: '2026-05-18', finish: '2026-06-15'
          task :beta_testing, 'Beta testing', start: '2026-06-08', finish: '2026-06-22'
        end
      end
    end
  end
end
