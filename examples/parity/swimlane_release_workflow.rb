# frozen_string_literal: true
require 'slim_graph_r'
module ParityFixtures
  module SwimlaneReleaseWorkflow
    module_function
    def diagram(theme: :light, style: :editorial)

      SlimGraphR.diagram(:swimlane, title: 'Publishing an article',
                         description: 'Four actors move an article from MDX draft through review, editing, approval, build, and Cloudflare Pages deployment. Named cross-lane arrows are explicit coordination handoffs.',
                         theme: theme, style: style) do
        lane :author, 'Author'
        lane :reviewer, 'Reviewer'
        lane :editor, 'Editor'
        lane :ci_cd, 'CI / CD'

        stage :draft, 'Draft'
        stage :open_pr, 'Open PR'
        stage :review, 'Review'
        stage :polish, 'Polish'
        stage :approve, 'Approve'
        stage :build, 'Build'
        stage :deploy, 'Deploy'

        activity :draft_mdx, 'Draft MDX', lane: :author, stage: :draft, detail: 'src/content/…'
        activity :open_pull_request, 'Open PR', lane: :author, stage: :open_pr, detail: 'gh pr create'
        activity :review_content, 'Review content', lane: :reviewer, stage: :review, detail: 'fact-check · voice'
        activity :polish_copy, 'Polish copy', lane: :editor, stage: :polish, detail: 'style · line edits'
        activity :approve_merge, 'Approve merge', lane: :editor, stage: :approve, detail: 'squash · main'
        activity :build_site, 'Build', lane: :ci_cd, stage: :build, detail: 'astro build'
        activity :deploy_site, 'Deploy', lane: :ci_cd, stage: :deploy, detail: 'cloudflare pages', focal: true

        handoff :draft_mdx, :open_pull_request
        handoff :open_pull_request, :review_content, 'HANDOFF'
        handoff :review_content, :polish_copy, 'REVISE', dashed: true
        handoff :polish_copy, :approve_merge
        handoff :approve_merge, :build_site, 'DEPLOY TRIGGER', focal: true
        handoff :build_site, :deploy_site
      end
    end
  end
end
