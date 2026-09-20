# frozen_string_literal: true
module SlimGraphR
  module Layout
    LoopBox = Struct.new(:record, :x, :y, :width, :height, :angle, :rect, keyword_init: true)
    LoopArc = Struct.new(:from_id, :to_id, :radius, :start_x, :start_y, :end_x, :end_y, :clockwise, :closure, keyword_init: true)
    LoopSpoke = Struct.new(:record, :start_x, :start_y, :end_x, :end_y, :label_x, :label_y, :dashed, :hub_gap, keyword_init: true)
    LoopScene = Struct.new(:width, :height, :radius, :center_x, :center_y, :station_boxes, :hub_box,
                           :cycle_arcs, :write_back_spokes, keyword_init: true)

    class Loop
      STATION_WIDTH = 160.0
      MAX_STATION_WIDTH = 208.0
      STATION_HEIGHT = 64.0
      HUB_WIDTH = 200.0
      HUB_HEIGHT = 104.0
      BASE_RADIUS = 240.0
      HUB_GAP = 6.0
      PRIMARY_TEXT_SIZE = 14
      METADATA_TEXT_SIZE = 12
      WIDTH = 1040.0
      HEIGHT = 680.0
      CENTER_X = WIDTH / 2.0
      CENTER_Y = 330.0

      def initialize(diagram) = @d = diagram

      def call
        station_width = measured_station_width
        validate_text!(station_width)
        radius = BASE_RADIUS
        ordered = @d.loop_cycle.map { |id| @d.loop_stations.find { |item| item.id == id } }
        boxes = ordered.map.with_index do |record, index|
          angle = -90.0 + index * 360.0 / ordered.size
          radians = angle * Math::PI / 180.0
          x = CENTER_X + Math.cos(radians) * radius
          y = CENTER_Y + Math.sin(radians) * radius
          LoopBox.new(record: record, x: x, y: y, width: station_width, height: STATION_HEIGHT, angle: angle,
                      rect: [x - station_width / 2, y - STATION_HEIGHT / 2, x + station_width / 2, y + STATION_HEIGHT / 2].freeze)
        end
        boxes.combination(2) do |left, right|
          raise LayoutError, 'Loop station cards overlap; shorten station text or split the loop' if self.class.overlap?(left.rect, right.rect)
        end
        hub_box = LoopBox.new(record: @d.loop_hub, x: CENTER_X, y: CENTER_Y, width: HUB_WIDTH, height: HUB_HEIGHT,
                              angle: nil, rect: [CENTER_X - HUB_WIDTH / 2, CENTER_Y - HUB_HEIGHT / 2,
                                                 CENTER_X + HUB_WIDTH / 2, CENTER_Y + HUB_HEIGHT / 2].freeze)
        arcs = boxes.each_with_index.map do |from, index|
          to = boxes[(index + 1) % boxes.size]
          start_angle = from.angle + card_angular_clearance(from.angle, station_width, radius)
          end_angle = to.angle - card_angular_clearance(to.angle, station_width, radius)
          start_x, start_y = point(radius, start_angle)
          end_x, end_y = point(radius, end_angle)
          LoopArc.new(from_id: from.record.id, to_id: to.record.id, radius: radius,
                      start_x: start_x, start_y: start_y, end_x: end_x, end_y: end_y,
                      clockwise: true, closure: index == boxes.size - 1)
        end
        station_by_id = boxes.to_h { |box| [box.record.id, box] }
        write_back_by_station = @d.loop_write_backs.to_h { |record| [record.from, record] }
        spokes = @d.loop_cycle.map { |id| write_back_by_station.fetch(id) }.map do |record|
          box = station_by_id.fetch(record.from)
          radians = box.angle * Math::PI / 180.0
          ux, uy = Math.cos(radians), Math.sin(radians)
          station_extent = ux.abs * station_width / 2 + uy.abs * STATION_HEIGHT / 2
          hub_extent = ux.abs * HUB_WIDTH / 2 + uy.abs * HUB_HEIGHT / 2
          start_x = box.x - ux * station_extent
          start_y = box.y - uy * station_extent
          end_x = CENTER_X + ux * (hub_extent + HUB_GAP)
          end_y = CENTER_Y + uy * (hub_extent + HUB_GAP)
          middle_x, middle_y = (start_x + end_x) / 2, (start_y + end_y) / 2
          LoopSpoke.new(record: record, start_x: start_x, start_y: start_y, end_x: end_x, end_y: end_y,
                        label_x: middle_x - uy * 10, label_y: middle_y + ux * 10, dashed: true, hub_gap: HUB_GAP)
        end
        LoopScene.new(width: WIDTH, height: HEIGHT, radius: radius, center_x: CENTER_X, center_y: CENTER_Y,
                      station_boxes: boxes.freeze, hub_box: hub_box.freeze, cycle_arcs: arcs.freeze,
                      write_back_spokes: spokes.freeze)
      end

      def self.overlap?(a, b)
        a[0] < b[2] && a[2] > b[0] && a[1] < b[3] && a[3] > b[1]
      end

      private

      def point(radius, angle)
        radians = angle * Math::PI / 180.0
        [CENTER_X + Math.cos(radians) * radius, CENTER_Y + Math.sin(radians) * radius]
      end

      def card_angular_clearance(angle, station_width, radius)
        radians = angle * Math::PI / 180.0
        tangent_x, tangent_y = -Math.sin(radians), Math.cos(radians)
        extent = tangent_x.abs * station_width / 2 + tangent_y.abs * STATION_HEIGHT / 2 + 10.0
        Math.asin(extent / radius) * 180.0 / Math::PI
      end

      def measured_station_width
        required = @d.loop_stations.flat_map { |item| [item.label, item.sublabel] }.compact
          .map { |text| Text.width(text, METADATA_TEXT_SIZE) + 20 }.max || STATION_WIDTH
        width = [STATION_WIDTH, Text.grid(required)].max
        if width > MAX_STATION_WIDTH
          value = @d.loop_stations.flat_map { |item| [item.label, item.sublabel] }.compact.max_by { |text| Text.width(text, METADATA_TEXT_SIZE) }
          raise LayoutError, "Loop station text #{value.inspect} exceeds the bounded #{MAX_STATION_WIDTH}px card; shorten the text or split the loop"
        end
        width
      end

      def validate_text!(station_width)
        check = lambda do |text, width, name, size|
          return unless text && Text.width(text, size) > width
          raise LayoutError, "Loop #{name} #{text.inspect} cannot fit its measured card; shorten the text or split the loop"
        end
        check.call(@d.loop_hub.label, 176, 'hub label', PRIMARY_TEXT_SIZE)
        check.call(@d.loop_hub.sublabel, 176, 'hub sublabel', METADATA_TEXT_SIZE)
        @d.loop_stations.each do |item|
          check.call(item.label, station_width - 20, 'station label', PRIMARY_TEXT_SIZE)
          check.call(item.sublabel, station_width - 20, 'station sublabel', METADATA_TEXT_SIZE)
        end
        @d.loop_write_backs.each { |item| check.call(item.label, 92, 'write-back label', METADATA_TEXT_SIZE) }
      end
    end
  end
end
