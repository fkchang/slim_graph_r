# frozen_string_literal: true

require 'slim_graph_r'

module ParityFixtures
  module JourneyTrialPaid
    module_function

    def diagram(theme: :light, style: :editorial)
      SlimGraphR.diagram :journey, title: 'Trial to paid · first week', persona: 'Independent analyst',
                         description: 'An independent analyst moves from sign up through first run and team invitation to a limit-induced trough before upgrading.', theme: theme, style: style do
        stage :sign_up, 'Sign up', sentiment: :high do
          action 'Create workspace'
          touchpoint 'signup form'
        end
        stage :first_run, 'First run', sentiment: :neutral do
          action 'Import first dataset'
          touchpoint 'onboarding wizard'
        end
        stage :invite_team, 'Invite team', sentiment: :high do
          action 'Add 3 teammates'
          touchpoint 'email invite'
        end
        stage :hit_limit, 'Hit the limit', sentiment: :low do
          action 'Export blocked mid-report'
          touchpoint 'in-app modal'
          pain 'NO WARNING AT 80%'
          pain 'PRICING PAGE IS 3 CLICKS AWAY'
        end
        stage :upgrade, 'Upgrade', sentiment: :neutral do
          action 'Pick annual plan'
          touchpoint 'billing page'
        end
      end
    end
  end
end
