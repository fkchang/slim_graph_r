# frozen_string_literal: true
module SlimGraphR
  # Curated profiles share readable body text; display fonts are measured before layout.
  class Style
    attr_reader :name, :light, :dark, :heading_font, :heading_family, :heading_weight,
                :node_radius, :node_inset, :border_width, :emphasis_width,
                :event_marker_radius, :emphasis_marker_radius

    def initialize(name, light:, dark:, heading_font: :serif, heading_weight: 400,
                   node_radius: 6, node_inset: 20, border_width: 1,
                   emphasis_width: 1.5, event_marker_radius: 4, emphasis_marker_radius: 6)
      @name, @heading_font, @heading_weight = name, heading_font, heading_weight
      @node_radius, @node_inset = node_radius, node_inset
      @border_width, @emphasis_width = border_width, emphasis_width
      @event_marker_radius, @emphasis_marker_radius = event_marker_radius, emphasis_marker_radius
      @heading_family = {
        serif: "'Instrument Serif',Georgia,serif",
        sans: "Geist,'Helvetica Neue',Arial,sans-serif",
        mono: "'Geist Mono',ui-monospace,monospace"
      }.fetch(heading_font).freeze
      @light, @dark = [light, dark].map { |palette| palette.transform_values { |v| v.freeze }.freeze }
      freeze
    end

    PROFILES = {
      editorial: new(:editorial,
        light: { paper: '#f5f5f5', secondary: '#ececec', ink: '#2d3142', muted: '#4f5d75', rule: '#bfc0c0', link: '#286aa6', accent: '#a83f18', tint: '#f8e7df' },
        dark: { paper: '#2d3142', secondary: '#393e53', ink: '#f5f5f5', muted: '#bfc0c0', rule: '#626b80', link: '#83bff1', accent: '#ffa374', tint: '#493c3b' }),
      ruby: new(:ruby, heading_font: :sans, heading_weight: 700,
        light: { paper: '#faf6ee', secondary: '#f0e9de', ink: '#241d1d', muted: '#625353', rule: '#baaba5', link: '#356c9c', accent: '#ad1733', tint: '#f5e2e4' },
        dark: { paper: '#211a1d', secondary: '#30272b', ink: '#fff7ee', muted: '#d1bfc4', rule: '#74616a', link: '#8fc5f0', accent: '#ff93a6', tint: '#42252f' }),
      blueprint: new(:blueprint, heading_font: :mono, heading_weight: 500,
        light: { paper: '#f4f8fc', secondary: '#e5edf5', ink: '#132d47', muted: '#3d5972', rule: '#9eb3c9', link: '#327ab8', accent: '#145da0', tint: '#ddeaf8' },
        dark: { paper: '#102438', secondary: '#1a334b', ink: '#f1f7ff', muted: '#bbd0e3', rule: '#59758e', link: '#6fb3ea', accent: '#88c8ff', tint: '#203f5b' }),
      mono: new(:mono, heading_font: :sans, heading_weight: 600,
        light: { paper: '#ffffff', secondary: '#eeeeee', ink: '#202020', muted: '#555555', rule: '#aaaaaa', link: '#202020', accent: '#111111', tint: '#e2e2e2' },
        dark: { paper: '#191919', secondary: '#292929', ink: '#f5f5f5', muted: '#cccccc', rule: '#737373', link: '#f5f5f5', accent: '#ffffff', tint: '#383838' }),
      minimal: new(:minimal, heading_font: :sans, heading_weight: 500,
        node_radius: 2, node_inset: 16, border_width: 1, emphasis_width: 2,
        event_marker_radius: 3, emphasis_marker_radius: 5,
        light: { paper: '#ffffff', secondary: '#f6f7f9', ink: '#18212f', muted: '#52606d', rule: '#b8c2cc', link: '#1d4ed8', accent: '#9f1239', tint: '#fce7ef' },
        dark: { paper: '#111827', secondary: '#1f2937', ink: '#f8fafc', muted: '#cbd5e1', rule: '#64748b', link: '#93c5fd', accent: '#fda4af', tint: '#4c1d2f' })
    }.freeze

    def self.names = PROFILES.keys.freeze
    def self.fetch(name)
      PROFILES.fetch(name.to_s.to_sym) { raise Error, "Unknown style #{name.inspect}. Choose #{names.join(', ')}." }
    end
  end
end
