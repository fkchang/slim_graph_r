# frozen_string_literal: true
require 'slim_graph_r/stream_weaver'

diagram :dependency, title: 'One shared requirement' do
  %i[app core plugins shared].each { |id| dependency id }
  depends_on :app, :core
  depends_on :app, :plugins
  depends_on :core, :shared
  depends_on :plugins, :shared
end

diagram :dependency, title: 'Runtime dependencies', style: :blueprint, theme: :dark do
  %i[app core plugins adapter hook].each { |id| dependency id }
  external_dependency :rack, 'Rack', version: '3.2.1', registry: 'RubyGems'
  depends_on :app, :core
  depends_on :app, :plugins
  depends_on :core, :adapter
  depends_on :plugins, :adapter
  depends_on :plugins, :hook
  depends_on :adapter, :rack
  depends_on :hook, :app, cycle: true
end
