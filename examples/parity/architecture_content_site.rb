# frozen_string_literal: true

require 'slim_graph_r'

# Semantic counterpart to Diagram Design's pinned Architecture content-site
# examples. It preserves the same pinned semantic payload for the supported
# presentation profiles; rendering remains supported-unverified until browser
# review records a parity decision.
module ParityFixtures
  module ArchitectureContentSite
    module_function

    def diagram(theme: :light, style: :editorial)
      profile = style.to_sym
      unless %i[editorial minimal].include?(profile)
        raise ArgumentError, 'Architecture content-site parity fixture supports minimal and full-editorial profiles'
      end

      SlimGraphR.diagram :architecture,
                         title: 'Content site in production',
                         description: 'Reader requests move through Cloudflare to an Astro origin, MDX bundle, and content CMS.',
                         theme: theme,
                         style: profile do
        external :reader, 'Reader', detail: 'Browser'
        node :cloudflare, 'Cloudflare', detail: 'Pages · cache'
        node :astro_origin, 'Astro Origin', detail: 'SSR + MDX', emphasis: true
        node :mdx_bundle, 'MDX Bundle', detail: 'src/content/*.mdx'
        store :content_cms, 'Content CMS', detail: 'assets · og images'

        edge :reader, :cloudflare, label: 'HTTPS'
        edge :cloudflare, :reader, label: 'RESP', dashed: true
        edge :cloudflare, :astro_origin, label: 'SSR'
        edge :astro_origin, :mdx_bundle, label: 'READ MDX'
        edge :astro_origin, :content_cms, label: 'QUERY'
      end
    end
  end
end
