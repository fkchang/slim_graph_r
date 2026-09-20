# frozen_string_literal: true
require 'date'
module SlimGraphR
  module Layout
    class Timeline
      CALLOUT_WIDTH = 224
      CALLOUT_HALF_WIDTH = CALLOUT_WIDTH / 2
      CALLOUT_GAP = 24
      EDGE_MARGIN = 16
      DATE_AXIS_WIDTH = 576
      DATE_AXIS_START = EDGE_MARGIN + CALLOUT_HALF_WIDTH
      DATE_SCENE_WIDTH = DATE_AXIS_START + DATE_AXIS_WIDTH + CALLOUT_HALF_WIDTH + EDGE_MARGIN

      def initialize(diagram) = @d = diagram
      def call
        return date_scaled if date_scaled?
        ordered
      end

      private

      def parsed_dates
        @parsed_dates ||= @d.events.map do |event|
          next unless event.date.match?(/\A\d{4}-\d{2}-\d{2}\z/)
          Date.iso8601(event.date, Date::GREGORIAN)
        rescue Date::Error, ArgumentError
          nil
        end
      end

      def date_scaled?
        return false if @d.scale == :ordered
        return true if @d.scale == :date && parsed_dates.all?
        return false if @d.scale == :auto && parsed_dates.any?(&:nil?)
        return true if @d.scale == :auto && parsed_dates.all?
        raise Error, 'Timeline scale :date requires every event date to be a valid YYYY-MM-DD calendar date'
      end

      def ordered
        y = 40
        events = @d.events.map do |event|
          lines, details = Text.wrap(event.label, 424, 18, font: @d.style_profile.heading_font), event.detail ? Text.wrap(event.detail, 424, 14) : []
          date_lines = Text.wrap(event.date, 112, 12)
          height = [Text.grid(lines.size * 24 + details.size * 20 + 40), date_lines.size * 16 + 24, 112].max
          result = { event: event, x: 208, y: y, lines: lines, details: details, date_lines: date_lines, height: height, above: false }
          y += height
          result
        end
        Scene.new(boxes: [], routes: [], zones: [], lifelines: [], events: events, width: 704, height: y + 24, axis: { mode: :ordered })
      end

      def date_scaled
        sorted = @d.events.zip(parsed_dates).each_with_index.sort_by { |(_event, date), index| [date, index] }.map(&:first)
        @first_date, @last_date = sorted.map(&:last).minmax
        groups = sorted.group_by(&:last).map { |date, rows| callout(date, rows.map(&:first)) }
        if groups.each_cons(2).any? { |a, b| b[:x] - a[:x] < 12 }
          raise LayoutError, 'Dates are too close to distinguish on this axis. Split the timeline or choose scale: :ordered explicitly.'
        end
        lanes = { above: [], below: [] }
        groups.each_with_index do |group, index|
          side = index.even? ? :above : :below
          lane = lanes[side].index do |members|
            members.all? { |other| (other[:x] - group[:x]).abs >= CALLOUT_WIDTH + CALLOUT_GAP }
          end || lanes[side].size
          lanes[side][lane] ||= []
          lanes[side][lane] << group
          group[:side], group[:lane] = side, lane
        end
        heights = lanes.transform_values { |list| list.map { |members| members.map { |g| g[:height] }.max } }
        above_height = heights[:above].sum + [heights[:above].size - 1, 0].max * 32
        below_height = heights[:below].sum + [heights[:below].size - 1, 0].max * 32
        baseline = 40 + above_height + 64
        groups.each do |group|
          offset = heights[group[:side]].first(group[:lane]).sum + group[:lane] * 32
          top = group[:side] == :above ? baseline - 64 - offset - group[:height] : baseline + 80 + offset
          group[:rect] = [group[:x] - CALLOUT_HALF_WIDTH, top, group[:x] + CALLOUT_HALF_WIDTH, top + group[:height]]
        end
        height = baseline + 80 + below_height + 64
        ticks = axis_ticks.map { |date| { x: date_x(date), label: date.iso8601 } }
        axis = { mode: :date, x1: date_x(@first_date), x2: date_x(@last_date), y: baseline,
                 ticks: ticks, callouts: groups, first: @first_date.iso8601, last: @last_date.iso8601,
                 caption: @first_date == @last_date ? 'Single calendar date — simultaneous events share one marker' : 'Calendar dates — linear spacing in elapsed days' }
        events = groups.flat_map { |g| g[:entries].map { |entry| entry.merge(x: g[:x], date: g[:date]) } }
        scene = Scene.new(boxes: [], routes: [], zones: [], lifelines: [], events: events, width: DATE_SCENE_WIDTH, height: height, axis: axis)
        route_leaders(scene)
        scene
      end

      def date_x(date)
        span = @last_date - @first_date
        return DATE_SCENE_WIDTH.fdiv(2) if span.zero?
        DATE_AXIS_START + (date - @first_date).to_f / span * DATE_AXIS_WIDTH
      end

      def callout(date, events)
        cursor = 24
        entries = events.map do |event|
          lines = Text.wrap(event.label, CALLOUT_WIDTH, 18, font: @d.style_profile.heading_font)
          details = event.detail ? Text.wrap(event.detail, CALLOUT_WIDTH, 14) : []
          entry = { event: event, lines: lines, details: details, offset: cursor }
          cursor += lines.size * 24 + (details.empty? ? 0 : 4 + details.size * 20) + 16
          entry
        end
        { date: date.iso8601, x: date_x(date), entries: entries, height: cursor,
          emphasis: events.any?(&:emphasis) }
      end

      def axis_ticks
        span = (@last_date - @first_date).to_i
        return [@first_date] if span.zero?
        step = [1, 2, 5, 7, 14, 30, 60, 90, 180, 365, 730, 1825, 3650, 36_500, 365_000, 3_650_000].find { |n| span.fdiv(n) <= 5 }
        dates = [@first_date]
        day = step
        while day < span
          date = @first_date + day
          dates << date if date_x(date) - date_x(dates.last) >= 112 && date_x(@last_date) - date_x(date) >= 112
          day += step
        end
        dates << @last_date
      end

      def route_leaders(scene)
        groups, baseline = scene.axis.values_at(:callouts, :y)
        boxes = groups.map do |group|
          x, y, r, b = group[:rect]
          Box.new(x: x, y: y, width: r - x, height: b - y)
        end
        boxes += scene.axis[:ticks].map { |tick| Box.new(x: tick[:x] - 48, y: baseline + 16, width: 96, height: 20) }
        connections = groups.map do |group|
          above = group[:side] == :above
          start = [group[:x], baseline + (above ? -8 : 8)]
          finish = [group[:x], above ? group[:rect][3] : group[:rect][1]]
          stub = [finish[0], finish[1] + (above ? 12 : -12)]
          [group, start, stub, finish]
        end
        router = Router.new(boxes, scene.width, scene.height, clearance: 8, portals: connections.flat_map { |_, start, stub, _| [start, stub] })
        connections.each do |group, start, stub, finish|
          points = Geometry.compact([ [group[:x], baseline] ] + router.route(start, stub) + [finish])
          router.commit(points)
          group[:leader] = points
        end
      rescue LayoutError
        raise LayoutError, 'Timeline callouts are too crowded to connect clearly. Split the timeline or choose scale: :ordered explicitly.'
      end
    end
  end
end
