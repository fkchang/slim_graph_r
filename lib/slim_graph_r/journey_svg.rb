# frozen_string_literal: true
module SlimGraphR
  class SVG
    private

    def draw_journey_family
      @d.type == :journey ? draw_journey : draw_story_map
    end

    def draw_journey
      text("PERSONA · #{@s.persona}", @s.label_margin, 14, class: 'sgr-journey-persona', 'data-sgr-persona': @s.persona)
      @s.headers.each do |entry|
        text(entry[:eyebrow], entry[:center], 34, class: 'sgr-journey-eyebrow', 'text-anchor': 'middle')
        first_y = entry[:label_lines].one? ? 56 : 48
        entry[:label_lines].each_with_index do |value, index|
          text(value, entry[:center], first_y + index * 14, class: 'sgr-journey-stage', 'text-anchor': 'middle',
               'data-sgr-stage-label': entry[:stage].id)
        end
      end
      @s.hairlines.each do |entry|
        line(@s.label_margin, entry[:y], @s.plot_right, entry[:y], 'var(--sgr-rule)')
        text(entry[:label], @s.label_margin - 8, entry[:y] + 3, class: 'sgr-journey-level', 'text-anchor': 'end',
             'data-sgr-sentiment-level': entry[:sentiment])
      end
      add %(<path #{attrs('data-sgr-sentiment-curve': 'ordinal-sequence', d: journey_curve_path(@s.curve),
                          fill: 'none', stroke: 'var(--sgr-muted)', 'stroke-width': 1.5)}/>)
      if @s.trough_segment
        add %(<path #{attrs('data-sgr-trough-incoming': @s.trough_segment.last[:stage].id,
                            d: journey_curve_path(@s.trough_segment), fill: 'none', stroke: 'var(--sgr-accent)',
                            'stroke-width': 1.8)}/>)
      end
      trough = @s.curve.max_by { |entry| Diagram::JOURNEY_SENTIMENT_RANK.fetch(entry[:stage].sentiment) }
      @s.curve.each do |entry|
        focal = entry.equal?(trough)
        add %(<circle #{attrs('data-sgr-journey-stage': entry[:stage].id,
                              'data-sgr-sentiment': entry[:stage].sentiment,
                              'data-sgr-trough': focal, cx: entry[:x], cy: entry[:y], r: 5,
                              fill: focal ? 'var(--sgr-accent)' : 'var(--sgr-muted)')}/>)
      end
      text(@s.caption[:text], @s.caption[:x], @s.caption[:y], class: 'sgr-journey-caption',
           'data-sgr-sentiment-caption': 'ordinal-not-measured')
      @s.rows.each do |row|
        line(@s.label_margin, row[:y], @s.plot_right, row[:y], 'var(--sgr-rule)')
        text(row[:label], @s.label_margin - 8, row[:y] + 18, class: 'sgr-journey-row-label', 'text-anchor': 'end',
             'data-sgr-row-label': row[:label])
      end
      @s.actions.each do |entry|
        entry[:lines].each_with_index do |value, index|
          text(value, entry[:x] + 10, @s.rows.first[:y] + 22 + index * 16, class: 'sgr-journey-action',
               'data-sgr-action': entry[:stage].id)
        end
      end
      touch_row = @s.rows.find { |row| row[:label] == 'TOUCHPOINTS' }
      if touch_row
        @s.touchpoints.each do |entry|
          entry[:lines].each_with_index do |value, index|
            text(value, entry[:x] + 10, touch_row[:y] + 22 + index * 14, class: 'sgr-journey-touchpoint',
                 'data-sgr-touchpoint': entry[:stage].id)
          end
        end
      end
      @s.pains.each do |entry|
        rect(entry[:x], entry[:y], entry[:width], entry[:height], rx: 2, fill: 'var(--sgr-tint)', 'fill-opacity': 0.5,
             stroke: 'var(--sgr-accent)', 'stroke-opacity': 0.7, 'stroke-width': 1, 'stroke-dasharray': '3 3',
             'data-sgr-pain': entry[:stage].id)
        text(entry[:value], entry[:x] + 8, entry[:y] + 16, class: 'sgr-journey-pain')
      end
      draw_journey_legend
    end

    def draw_journey_legend
      y = @s.legend[:y]
      origin = @s.label_margin
      line(origin, y - 10, @s.plot_right, y - 10, 'var(--sgr-rule)')
      line(origin + 8, y + 9, origin + 32, y + 9, 'var(--sgr-muted)')
      text('Sentiment sequence', origin + 40, y + 13, class: 'sgr-journey-legend')
      add %(<circle cx="#{origin + 166}" cy="#{y + 9}" r="5" fill="var(--sgr-accent)"/>)
      text('Unique trough', origin + 180, y + 13, class: 'sgr-journey-legend')
      rect(origin + 272, y + 2, 26, 14, rx: 2, fill: 'var(--sgr-tint)', stroke: 'var(--sgr-accent)',
           'stroke-width': 1, 'stroke-dasharray': '3 3')
      text('Pain marker', origin + 308, y + 13, class: 'sgr-journey-legend')
    end

    def draw_story_map
      text("PERSONA · #{@s.persona}", Layout::StoryMap::LEFT, 14, class: 'sgr-story-persona', 'data-sgr-persona': @s.persona)
      @s.guides.each do |guide|
        line(guide[:x], guide[:y1], guide[:x], guide[:y2], 'var(--sgr-rule)', dashed: true, dash_pattern: '4 4')
        add %(<g data-sgr-column-guide="#{esc(guide[:activity].id)}"/>)
      end
      @s.activities.each do |entry|
        item = entry[:activity]
        rect(entry[:x], entry[:y], entry[:width], entry[:height], rx: 6, fill: 'var(--sgr-ink)', 'fill-opacity': 0.05,
             stroke: 'var(--sgr-muted)', 'stroke-width': 0.8, 'data-sgr-activity': item.id)
        text(entry[:eyebrow], entry[:x] + 12, entry[:y] + 17, class: 'sgr-story-eyebrow')
        entry[:lines].each_with_index do |value, index|
          text(value, entry[:x] + 12, entry[:y] + 37 + index * 14, class: 'sgr-story-activity')
        end
      end
      @s.steps.each do |entry|
        rect(entry[:x], entry[:y], entry[:width], entry[:height], rx: 4, fill: 'var(--sgr-paper)',
             stroke: 'var(--sgr-ink)', 'stroke-width': 0.8, 'data-sgr-step': entry[:step].id,
             'data-sgr-step-activity': entry[:activity].id)
        text(entry[:lines].first, entry[:x] + 10, entry[:y] + 21, class: 'sgr-story-step')
      end
      @s.releases.each_with_index do |entry, index|
        item = entry[:release]
        rect(entry[:x], entry[:y], entry[:width], entry[:height], fill: 'var(--sgr-ink)',
             'fill-opacity': index.even? ? 0.025 : 0, 'data-sgr-release': item.id,
             'data-sgr-release-label': item.label)
        text(item.label, Layout::StoryMap::LEFT - 16, entry[:y] + 24, class: 'sgr-story-release', 'text-anchor': 'end')
      end
      @s.stories.each { |entry| draw_story_card(entry) }
      @s.cuts.each do |entry|
        line(0, entry[:y], @s.width, entry[:y], 'var(--sgr-accent)')
        label_width = 72
        rect(@s.width - label_width - 4, entry[:y] - 8, label_width, 16, fill: 'var(--sgr-paper)')
        text('RELEASE CUT', @s.width - 8, entry[:y] + 3, class: 'sgr-story-tag', 'text-anchor': 'end',
             'data-sgr-release-cut': entry[:release].id)
      end
      draw_story_legend
    end

    def draw_story_card(entry)
      story = entry[:story]
      fill = story.risk ? 'var(--sgr-tint)' : 'var(--sgr-paper)'
      stroke = story.risk ? 'var(--sgr-accent)' : 'var(--sgr-ink)'
      rect(entry[:x], entry[:y], entry[:width], entry[:height], rx: 4, fill: fill, 'fill-opacity': story.risk ? 0.65 : 1,
           stroke: stroke, 'stroke-width': 0.9, 'stroke-dasharray': story.risk ? '4 4' : nil,
           'data-sgr-story': story.id, 'data-sgr-story-activity': story.activity,
           'data-sgr-story-release': entry[:release].id, 'data-sgr-story-risk': story.risk ? story.id : nil)
      if story.risk
        rect(entry[:x] + entry[:width] - 42, entry[:y] + 7, 32, 14, rx: 2, fill: 'var(--sgr-paper)',
             stroke: 'var(--sgr-accent)', 'stroke-width': 0.8)
        text('RISK', entry[:x] + entry[:width] - 26, entry[:y] + 17, class: 'sgr-story-tag', 'text-anchor': 'middle')
      end
      title_y = if entry[:metadata].empty?
        entry[:y] + (entry[:lines].one? ? 29 : 20)
      else
        entry[:y] + 17
      end
      entry[:lines].each_with_index do |value, index|
        text(value, entry[:x] + 10, title_y + index * 14, class: 'sgr-story-title')
      end
      unless entry[:metadata].empty?
        text(entry[:metadata], entry[:x] + 10, entry[:y] + 41, class: 'sgr-story-meta',
             'data-sgr-story-metadata': story.id)
      end
    end

    def draw_story_legend
      y = @s.legend[:y]
      origin = Layout::StoryMap::LEFT
      line(origin, y - 10, @s.width, y - 10, 'var(--sgr-rule)')
      rect(origin + 8, y + 1, 28, 16, rx: 3, fill: 'var(--sgr-paper)', stroke: 'var(--sgr-ink)', 'stroke-width': 0.8)
      text('Story', origin + 46, y + 14, class: 'sgr-story-legend')
      rect(origin + 130, y + 1, 28, 16, rx: 3, fill: 'var(--sgr-tint)', stroke: 'var(--sgr-accent)', 'stroke-width': 0.8, 'stroke-dasharray': '4 4')
      text('Risk', origin + 168, y + 14, class: 'sgr-story-legend')
      line(origin + 246, y + 9, origin + 278, y + 9, 'var(--sgr-accent)')
      text('Release cut', origin + 288, y + 14, class: 'sgr-story-legend')
    end

    def journey_curve_path(points)
      return '' if points.empty?
      commands = ["M #{journey_coord(points.first[:x])} #{journey_coord(points.first[:y])}"]
      points.each_cons(2) do |left, right|
        distance = (right[:x] - left[:x]) / 3.0
        commands << "C #{journey_coord(left[:x] + distance)} #{journey_coord(left[:y])} #{journey_coord(right[:x] - distance)} #{journey_coord(right[:y])} #{journey_coord(right[:x])} #{journey_coord(right[:y])}"
      end
      commands.join(' ')
    end

    def journey_coord(value)
      value.respond_to?(:to_i) && value == value.to_i ? value.to_i : value.round(3)
    end

    def journey_family_description
      return @d.description if @d.description
      if @d.type == :journey
        stages = @d.journey_stages.map do |item|
          parts = ["action #{item.action}", item.touchpoint && "touchpoint #{item.touchpoint}",
                   "ordinal sentiment #{item.sentiment.to_s.tr('_', ' ')}"]
          parts << "pains #{item.pains.join(', ')}" unless item.pains.empty?
          "#{item.label}: #{parts.compact.join('; ')}"
        end.join('. ')
        trough = @d.journey_stages.max_by { |item| Diagram::JOURNEY_SENTIMENT_RANK.fetch(item.sentiment) }
        "Journey for persona #{@d.persona}. Stages in declaration order: #{stages}. The unique trough is #{trough.label}. Sentiment levels are ordinal, not measured scores. The curve conveys stage sequence only."
      else
        activities = @d.story_activities.map do |item|
          "#{item.label}, steps in order: #{item.steps.map(&:label).join(', ')}"
        end.join('. ')
        releases = @d.story_releases.map do |release|
          stories = release.stories.map do |story|
            metadata = [story.ticket && "ticket #{story.ticket}", story.estimate && "estimate #{story.estimate}", story.risk ? 'risk' : nil].compact
            "#{story.label} under #{@d.story_activities.find { |item| item.id == story.activity }.label}#{metadata.empty? ? '' : ", #{metadata.join(', ')}"}"
          end.join('; ')
          "#{release.label}#{release.cut ? ', release cut follows' : ''}: #{stories}"
        end.join('. ')
        "Story map for persona #{@d.persona}. Activities in narrative declaration order: #{activities}. Releases in declaration order with literal labels and no calendar semantics: #{releases}. Row position does not infer state, sentiment, dependency, or priority."
      end
    end
  end
end
