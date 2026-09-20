# frozen_string_literal: true

require 'slim_graph_r'

# Semantic counterpart to Diagram Design's pinned cold-cache article request.
# It preserves the actor roles, control intervals, synchronous calls, returns,
# primary response, and asynchronous pageview beacon.
module ParityFixtures
  module SequenceArticleRequest
    module_function

    def diagram(theme: :light, style: :editorial)
      profile = style.to_sym
      unless %i[editorial minimal].include?(profile)
        raise ArgumentError, 'Sequence article-request parity fixture supports minimal and full-editorial profiles'
      end

      SlimGraphR.diagram :sequence,
                         title: 'Article request, cold cache',
                         description: 'Reader requests an article from Cloudflare, which misses cache and asks Astro Origin to render MDX before returning an edge-cached response and sending a pageview beacon.',
                         theme: theme,
                         style: profile do
        participant :reader, 'Reader', detail: 'Browser', kind: :external
        participant :cloudflare, 'Cloudflare', detail: 'Pages · cache'
        participant :astro_origin, 'Astro Origin', detail: 'SSR + MDX', emphasis: true
        participant :analytics, 'Analytics', detail: 'Beacon · async'

        message :reader, :cloudflare, 'GET /ARTICLES/SLUG'
        activate :cloudflare do
          message :cloudflare, :astro_origin, 'CACHE MISS · ORIGIN'
          activate :astro_origin do
            message :astro_origin, :astro_origin, 'RENDER MDX'
            reply :astro_origin, :cloudflare, '200 · HTML + MAX-AGE'
          end
          message :cloudflare, :reader, '200 · EDGE-CACHED', kind: :success
        end
        notify :reader, :analytics, 'PAGEVIEW BEACON'
      end
    end
  end
end
