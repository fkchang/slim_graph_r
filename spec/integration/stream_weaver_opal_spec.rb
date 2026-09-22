# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require_relative '../spec_helper'

RSpec.describe 'the browser-safe StreamWeaver entrypoint' do
  it 'adds the diagram DSL to an existing StreamWeaver runtime without loading the server entrypoint' do
    script = <<~'RUBY'
      module StreamWeaver
        module Components
          class Base
            def initialize(*) = nil
          end
        end
        module DisplayDSL; end
      end

      require 'slim_graph_r/stream_weaver_opal'

      host_class = Class.new do
        include StreamWeaver::DisplayDSL
        attr_reader :components
        def initialize = @components = []
      end
      component = host_class.new.diagram(:architecture, title: 'Browser safe') { node :ready, 'Ready' }

      puts component.diagram.to_svg(id: 'browser-safe').include?('<title id="browser-safe-title">Browser safe</title>')
      puts $LOADED_FEATURES.grep(%r{/stream_weaver\.rb$}).empty?
    RUBY

    stdout, stderr, status = Bundler.with_unbundled_env do
      Open3.capture3(
        { 'BUNDLE_GEMFILE' => nil, 'BUNDLE_BIN_PATH' => nil, 'RUBYOPT' => nil, 'RUBYLIB' => nil },
        RbConfig.ruby, '-I', File.expand_path('../../lib', __dir__), '-e', script
      )
    end

    expect(status).to be_success, stderr
    expect(stdout.lines.map(&:strip)).to eq(%w[true true])
  end
end
