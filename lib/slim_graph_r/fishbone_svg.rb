# frozen_string_literal: true
module SlimGraphR
  class SVG
    def draw_fishbone
      add %(<line x1="#{fishbone_number(@s.spine_start_x)}" y1="#{fishbone_number(@s.center_y)}" x2="#{fishbone_number(@s.spine_end_x)}" y2="#{fishbone_number(@s.center_y)}" stroke="var(--sgr-ink)" stroke-width="1.2" marker-end="url(##{@id}-arrow)" data-sgr-fishbone-spine="true"/> )
      @s.bones.each do |bone|
        add %(<line x1="#{fishbone_number(bone.attach_x)}" y1="#{fishbone_number(bone.attach_y)}" x2="#{fishbone_number(bone.far_x)}" y2="#{fishbone_number(bone.far_y)}" stroke="#{bone.record.confirmed ? 'var(--sgr-accent)' : 'var(--sgr-muted)'}" stroke-width="1.2" data-sgr-fishbone-bone="#{esc(bone.record.id)}" data-sgr-fishbone-confirmed="#{bone.record.confirmed}" data-sgr-fishbone-side="#{bone.record.side}" data-sgr-fishbone-angle="60"/> )
      end
      @s.ticks.each_with_index do |tick, index|
        add %(<line x1="#{fishbone_number(tick.start_x)}" y1="#{fishbone_number(tick.start_y)}" x2="#{fishbone_number(tick.end_x)}" y2="#{fishbone_number(tick.end_y)}" stroke="var(--sgr-rule)" stroke-width="1" data-sgr-fishbone-tick="#{esc("#{tick.category_id}:#{index}")}" data-sgr-fishbone-tick-length="32"/> )
      end
      @s.category_boxes.each do |box|
        x, y, right, bottom = box.rect
        rect(x, y, right - x, bottom - y, fill: box.record.confirmed ? 'var(--sgr-tint)' : 'var(--sgr-paper)', stroke: box.record.confirmed ? 'var(--sgr-accent)' : 'var(--sgr-muted)', rx: 4,
             'data-sgr-fishbone-category': box.record.id, 'data-sgr-fishbone-confirmed': box.record.confirmed)
      end
      box = @s.effect_box
      effect_x, effect_y, effect_right, effect_bottom = box.rect
      confirmed = @d.fishbone_categories.any?(&:confirmed)
      rect(effect_x, effect_y, effect_right - effect_x, effect_bottom - effect_y, fill: confirmed ? 'var(--sgr-tint)' : 'var(--sgr-secondary)', stroke: confirmed ? 'var(--sgr-accent)' : 'var(--sgr-ink)', 'stroke-width': 1.2, rx: 6,
           'data-sgr-effect': 'true', 'data-sgr-effect-headline': 'true')
      @s.ticks.each do |tick|
        text(tick.factor, tick.label_x, tick.label_y, class: 'sgr-fishbone-factor', 'text-anchor': 'end',
             'data-sgr-fishbone-factor': tick.category_id)
      end
      @s.category_boxes.each do |category_box|
        x, y, right, bottom = category_box.rect
        text(category_box.record.label, (x + right) / 2, (y + bottom) / 2 + 5, class: 'sgr-fishbone-category', 'text-anchor': 'middle')
      end
      start_y = @s.center_y - (box.lines.size - 1) * 19 / 2.0 + 5
      box.lines.each_with_index do |line_value, index|
        text(line_value, (effect_x + effect_right) / 2, start_y + index * 19, class: 'sgr-fishbone-effect', 'text-anchor': 'middle')
      end
      if confirmed
        add %(<g data-sgr-fishbone-legend="true"><line x1="40" y1="590" x2="62" y2="590" stroke="var(--sgr-accent)" stroke-width="1.2"/><text x="72" y="594" class="sgr-fishbone-factor">CONFIRMED ROOT CATEGORY</text></g>)
      end
    end

    def fishbone_description
      return @d.description if @d.description
      categories = @d.fishbone_categories.map do |item|
        "#{item.label}: #{item.factors.join(', ')} (#{item.side})"
      end.join('. ')
      confirmed = @d.fishbone_categories.find(&:confirmed)
      conclusion = confirmed ? " Confirmed root category: #{confirmed.label}." : ' These are investigated or associated leads and do not prove causation.'
      "Observed effect: #{@d.fishbone_effect.label}. Investigated categories and associated factors: #{categories}.#{conclusion}"
    end

    def fishbone_number(value)
      format('%.3f', value).sub(/\.0+\z/, '').sub(/(\.\d*?)0+\z/, '\\1')
    end
  end
end
