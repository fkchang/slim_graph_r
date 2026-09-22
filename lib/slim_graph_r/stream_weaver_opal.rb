# frozen_string_literal: true
# backtick_javascript: true

# Browser-safe integration for a StreamWeaver runtime that is already loaded.
# This entrypoint deliberately avoids `require "stream_weaver"`, whose server
# tree includes Sinatra, Phlex, and other code that cannot run in Opal.
require 'slim_graph_r/opal_compat'
require 'slim_graph_r'

module SlimGraphR
  class StreamWeaverComponent < StreamWeaver::Components::Base
    attr_reader :diagram

    def initialize(diagram)
      super()
      @diagram = diagram
    end

    def storyboard(&block)
      @diagram = diagram.storyboard(&block)
      self
    end

    def render(view, _state)
      markup = if diagram.is_a?(SlimGraphR::Motion::Presentation)
        diagram.fragment(include_script: RUBY_ENGINE != 'opal')
      else
        diagram.to_svg
      end
      view.div(style: 'overflow-x:auto;max-width:100%;margin:32px 0', tabindex: '0', role: 'region', 'aria-label': diagram.title) do
        view.raw(view.safe(markup))
      end
    end
  end

  module StreamWeaverDSL
    def diagram(type = :architecture, **options, &block)
      model = SlimGraphR.diagram(type, **options, &block)
      component = StreamWeaverComponent.new(model)
      components << component
      component
    end
  end
end

StreamWeaver::DisplayDSL.include(SlimGraphR::StreamWeaverDSL)
# Opal caches the method table when App includes DisplayDSL. Because the
# packaged runtime loads extensions after App, include the narrow DSL on App
# as well so self-hosted code compiled later can dispatch `diagram` directly.
StreamWeaver::App.include(SlimGraphR::StreamWeaverDSL) if defined?(StreamWeaver::App)

# Saved documents use the public MRI require path. The extension eagerly loads
# this narrow entrypoint, so teach Opal that the public path is already present
# without compiling SlimGraphR's server-side StreamWeaver require tree.
if RUBY_ENGINE == 'opal'
  %x{ Opal.loaded(["slim_graph_r/stream_weaver"]); }
end
