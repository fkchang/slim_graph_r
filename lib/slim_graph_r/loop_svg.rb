# frozen_string_literal: true
module SlimGraphR
  class SVG
    def draw_loop
      @s.cycle_arcs.each do |arc|
        add %(<path d="M #{loop_number(arc.start_x)} #{loop_number(arc.start_y)} A #{loop_number(arc.radius)} #{loop_number(arc.radius)} 0 0 1 #{loop_number(arc.end_x)} #{loop_number(arc.end_y)}" fill="none" stroke="var(--sgr-muted)" stroke-width="1.5" marker-end="url(##{@id}-arrow)" data-sgr-loop-cycle-arc="#{esc("#{arc.from_id}→#{arc.to_id}")}" data-sgr-loop-closure="#{arc.closure}"/> )
      end
      @s.write_back_spokes.each do |spoke|
        add %(<path d="M #{loop_number(spoke.start_x)} #{loop_number(spoke.start_y)} L #{loop_number(spoke.end_x)} #{loop_number(spoke.end_y)}" fill="none" stroke="var(--sgr-rule)" stroke-width="1.2" stroke-dasharray="5 4" marker-end="url(##{@id}-arrow)" data-sgr-loop-write-back="#{esc(spoke.record.from)}" data-sgr-loop-hub-gap="6"/> )
        next unless spoke.record.label
        text(spoke.record.label, spoke.label_x, spoke.label_y, class: 'sgr-loop-write-label', 'text-anchor': 'middle',
             'data-sgr-loop-write-label': spoke.record.from)
      end
      draw_loop_hub(@s.hub_box)
      @s.station_boxes.each { |box| draw_loop_station(box) }
    end

    def draw_loop_hub(box)
      rect(box.rect[0], box.rect[1], box.width, box.height, fill: 'var(--sgr-ink)', stroke: 'var(--sgr-ink)', rx: 8,
           'data-sgr-loop-hub': box.record.id)
      text(box.record.label, box.x, box.y - (box.record.sublabel ? 5 : -5), class: 'sgr-loop-hub-name',
           'text-anchor': 'middle')
      text(box.record.sublabel, box.x, box.y + 18, class: 'sgr-loop-hub-detail', 'text-anchor': 'middle') if box.record.sublabel
    end

    def draw_loop_station(box)
      record = box.record
      rect(box.rect[0], box.rect[1], box.width, box.height,
           fill: record.focal ? 'var(--sgr-tint)' : 'var(--sgr-paper)',
           stroke: record.focal ? 'var(--sgr-accent)' : 'var(--sgr-ink)', 'stroke-width': record.focal ? 1.5 : 1, rx: 6,
           'data-sgr-loop-station': record.id, 'data-sgr-loop-angle': loop_number(box.angle), 'data-sgr-loop-focal': record.focal ? 'true' : nil)
      text(record.label, box.x, box.y - (record.sublabel ? 3 : -5), class: "sgr-loop-station-name#{record.focal ? ' sgr-loop-focal' : ''}",
           'text-anchor': 'middle')
      text(record.sublabel, box.x, box.y + 18, class: 'sgr-loop-station-detail', 'text-anchor': 'middle') if record.sublabel
    end

    def loop_description
      return @d.description if @d.description
      names = @d.loop_stations.to_h { |item| [item.id, item.label] }
      route = (@d.loop_cycle + [@d.loop_cycle.first]).map { |id| names.fetch(id) }.join(' → ')
      write_back_by_station = @d.loop_write_backs.to_h { |item| [item.from, item] }
      writes = @d.loop_cycle.map { |id| write_back_by_station.fetch(id) }.map do |item|
        "#{names.fetch(item.from)} writes back to #{@d.loop_hub.label}#{item.label ? " (#{item.label})" : ''}"
      end.join('. ')
      focal = @d.loop_stations.find(&:focal)
      "A clockwise loop with shared state in #{@d.loop_hub.label}. Cycle: #{route}. #{writes}.#{focal ? " #{focal.label} is the author-selected focal station." : ''}"
    end


    def loop_number(value)
      format('%.3f', value).sub(/\.0+\z/, '').sub(/(\.\d*?)0+\z/, '\\1')
    end
  end
end
