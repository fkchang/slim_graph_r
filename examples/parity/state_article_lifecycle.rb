# frozen_string_literal: true

require 'slim_graph_r'

module ParityFixtures
  module StateArticleLifecycle
    module_function

    def diagram(theme: :light, style: :editorial)

      SlimGraphR.diagram :state,
                         title: 'Article lifecycle',
                         description: 'State machine showing an article moving from Draft through In Review and Published to Archived, including rejection and revision.',
                         direction: :right,
                         theme: theme,
                         style: style do
        state :draft, 'Draft', detail: 'unpublished'
        state :in_review, 'In Review', detail: 'awaiting approval'
        state :published, 'Published', detail: 'live on site', emphasis: true
        state :archived, 'Archived', detail: 'noindex · hidden\nredirect retained'
        initial :draft
        final :archived
        transition :draft, :in_review, on: 'submit'
        transition :in_review, :published, on: 'approve'
        transition :published, :archived, on: 'expire'
        transition :in_review, :draft, on: 'reject · revise'
      end
    end
  end
end
