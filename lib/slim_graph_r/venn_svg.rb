# frozen_string_literal: true
module SlimGraphR
  class SVG
    def draw_venn
      draw_venn_focal_clip if @s.focal
      @s.circles.each_with_index do |circle, index|
        add %(<circle #{attrs(cx: circle.cx, cy: circle.cy, r: circle.r,
                              fill: 'var(--sgr-ink)', 'fill-opacity': '0.055',
                              stroke: index.zero? ? 'var(--sgr-ink)' : 'var(--sgr-muted)', 'stroke-width': 1,
                              'data-sgr-venn-circle': circle.set.id)}/>)
      end
      @s.set_labels.each do |entry|
        text(entry.text, entry.x, entry.y, class: 'sgr-venn-set-label', 'text-anchor': 'middle',
             'data-sgr-venn-set-label': entry.record.id)
        text(entry.subtitle, entry.x, entry.subtitle_y, class: 'sgr-venn-set-subtitle', 'text-anchor': 'middle',
             'data-sgr-venn-set-subtitle': entry.record.id) if entry.subtitle
      end
      @s.region_labels.each do |entry|
        record = entry.record
        text(entry.text, entry.x, entry.y, class: "sgr-venn-region-label#{record.focal ? ' sgr-venn-focal' : ''}",
             'text-anchor': 'middle', 'data-sgr-venn-region-label': record.sets.join(','),
             'data-sgr-venn-focal': record.focal ? 'true' : nil)
      end
      text(@s.caption, @s.width / 2.0, @s.height - 12, class: 'sgr-venn-caption', 'text-anchor': 'middle',
           'data-sgr-venn-caption': 'true')
    end

    def draw_venn_focal_clip
      members = @s.focal.sets.map { |id| @s.circles.find { |circle| circle.set.id == id } }
      members.each_with_index do |circle, index|
        suffix = index.zero? ? 'venn-focal-clip' : "venn-focal-clip-#{index + 1}"
        add %(<defs><clipPath id="#{@id}-#{suffix}" data-sgr-venn-focal-clip="#{index.zero? ? 'true' : 'member'}"><circle cx="#{circle.cx}" cy="#{circle.cy}" r="#{circle.r}"/></clipPath></defs>)
      end
      groups = members.each_index.map do |index|
        suffix = index.zero? ? 'venn-focal-clip' : "venn-focal-clip-#{index + 1}"
        %(<g clip-path="url(##{@id}-#{suffix})">)
      end.join
      add "#{groups}<rect x=\"0\" y=\"0\" width=\"#{@s.width}\" height=\"#{@s.height}\" fill=\"var(--sgr-accent)\" fill-opacity=\"0.11\" data-sgr-venn-focal-region=\"#{esc(@s.focal.sets.join(','))}\"/>#{'</g>' * members.size}"
    end

    def venn_description
      return @d.description if @d.description
      names = @d.venn_sets.to_h { |item| [item.id, item.label] }
      regions = @d.intersections.map do |item|
        "#{item.sets.map { |id| names.fetch(id) }.join(' ∩ ')}: #{item.label}#{item.focal ? '; author-selected focal overlap' : ''}."
      end
      sets = @d.venn_sets.map { |item| "#{item.label}#{item.subtitle ? ": #{item.subtitle}" : ''}" }.join(', ')
      "Venn set topology. Sets: #{sets}. #{regions.join(' ')} Equal circles encode named topology only; area and population are not quantitative."
    end
  end
end
