# frozen_string_literal: true
module SlimGraphR
  module Layout
    JourneyScene = Struct.new(
      :width, :height, :label_margin, :plot_right, :persona, :headers, :hairlines, :curve, :trough_segment,
      :actions, :touchpoints, :pains, :rows, :caption, :legend,
      keyword_init: true
    )
    StoryMapScene = Struct.new(
      :width, :height, :persona, :activities, :steps, :releases, :stories,
      :guides, :cuts, :legend,
      keyword_init: true
    )

    class Journey
      MIN_LEFT = 112
      RIGHT_PADDING = 4
      COLUMN_WIDTH = 224
      MAX_COLUMN_WIDTH = 304
      GUTTER = 24
      PLOT_TOP = 72
      PLOT_HEIGHT = 160
      LEVEL_STEP = 40
      CAPTION_Y = 256
      ROW_TOP = 276
      ROW_HEIGHT = 52
      PAIN_HEIGHT = 24
      PAIN_GAP = 6

      def initialize(diagram) = @d = diagram

      def call
        label_margin = measured_label_margin
        column_widths = @d.journey_stages.map { |stage| measured_column_width(stage) }
        column_xs = []
        column_widths.each do |column_width|
          column_xs << (column_xs.empty? ? label_margin : column_xs.last + column_widths[column_xs.size - 1] + GUTTER)
        end
        plot_right = column_xs.last + column_widths.last
        width = plot_right + RIGHT_PADDING
        ensure_persona_fits!(width, label_margin)
        headers = []
        actions = []
        touchpoints = []
        pains = []
        points = []
        @d.journey_stages.each_with_index do |stage, index|
          x = column_xs.fetch(index)
          column_width = column_widths.fetch(index)
          center = x + column_width / 2
          eyebrow = "STAGE #{index + 1}"
          ensure_tracked_fit!(eyebrow, column_width, 12, "journey stage eyebrow #{eyebrow.inspect}")
          label_lines = measured_lines(stage.label, column_width - 16, 14, 2, "Journey stage label #{stage.label.inspect}")
          headers << { stage: stage, x: x, center: center, width: column_width, eyebrow: eyebrow, label_lines: label_lines }
          points << { stage: stage, x: center, y: PLOT_TOP + Diagram::JOURNEY_SENTIMENT_RANK.fetch(stage.sentiment) * LEVEL_STEP }
          actions << cell(stage, x, column_width, stage.action, 14, 2, 'action')
          touchpoints << cell(stage, x, column_width, stage.touchpoint, 12, 1, 'touchpoint', font: :mono) if stage.touchpoint
        end
        used = points.map { |item| item[:stage].sentiment }.uniq
        hairlines = Diagram::JOURNEY_SENTIMENTS.filter_map.with_index do |sentiment, index|
          next unless used.include?(sentiment)
          label = { medium_high: 'MED-HIGH', medium_low: 'MED-LOW' }.fetch(sentiment, sentiment.to_s.upcase)
          ensure_tracked_fit!(label, label_margin - 12, 12, "journey sentiment label #{label.inspect}")
          { sentiment: sentiment, label: label, y: PLOT_TOP + index * LEVEL_STEP }
        end
        trough_index = points.each_index.max_by { |index| Diagram::JOURNEY_SENTIMENT_RANK.fetch(points[index][:stage].sentiment) }
        cursor = ROW_TOP + ROW_HEIGHT
        rows = [{ label: 'ACTIONS', y: ROW_TOP, height: ROW_HEIGHT }]
        if touchpoints.any?
          rows << { label: 'TOUCHPOINTS', y: cursor, height: ROW_HEIGHT }
          cursor += ROW_HEIGHT
        end
        if @d.journey_stages.any? { |stage| !stage.pains.empty? }
          max_pains = @d.journey_stages.map { |stage| stage.pains.size }.max
          pain_row_height = 20 + max_pains * PAIN_HEIGHT + [max_pains - 1, 0].max * PAIN_GAP + 10
          rows << { label: 'PAINS', y: cursor, height: pain_row_height }
          @d.journey_stages.each_with_index do |stage, index|
            x = column_xs.fetch(index)
            column_width = column_widths.fetch(index)
            stage.pains.each_with_index do |value, pain_index|
              pains << { stage: stage, value: value, x: x + 8, y: cursor + 20 + pain_index * (PAIN_HEIGHT + PAIN_GAP), width: column_width - 16, height: PAIN_HEIGHT }
            end
          end
          cursor += pain_row_height
        end
        legend_y = cursor + 18
        JourneyScene.new(
          width: width, height: legend_y + 50, label_margin: label_margin, plot_right: plot_right,
          persona: @d.persona, headers: headers, hairlines: hairlines,
          curve: points, trough_segment: trough_index.positive? ? [points[trough_index - 1], points[trough_index]] : nil,
          actions: actions, touchpoints: touchpoints, pains: pains, rows: rows,
          caption: { text: 'Sentiment levels are ordinal, not measured scores', x: label_margin, y: CAPTION_Y },
          legend: { y: legend_y }
        )
      end

      private

      def measured_label_margin
        labels = %w[TOUCHPOINTS ACTIONS PAINS MED-HIGH NEUTRAL MED-LOW]
        measured = labels.map { |value| tracked_width(value, 12, :mono, 0.14) }.max
        [MIN_LEFT, Text.grid(measured + 16)].max
      end

      def ensure_persona_fits!(width, label_margin)
        label = "PERSONA · #{@d.persona}"
        raise LayoutError, 'Journey persona does not fit the available width; shorten it' if tracked_width(label, 12, :mono, 0.08) > width - label_margin
      end

      def cell(stage, x, width, value, size, max_lines, kind, font: :sans)
        lines = measured_lines(value, width - 20, size, max_lines, "Journey #{kind} #{value.inspect}", font: font)
        { stage: stage, x: x, width: width, lines: lines }
      end

      def measured_column_width(stage)
        pain_width = stage.pains.map { |value| tracked_width(value, 12, :mono, 0.03) + 24 }.max || COLUMN_WIDTH
        width = [COLUMN_WIDTH, Text.grid(pain_width)].max
        if width > MAX_COLUMN_WIDTH
          value = stage.pains.max_by { |pain| tracked_width(pain, 12, :mono, 0.03) }
          raise LayoutError, "Journey pain #{value.inspect} exceeds the bounded #{MAX_COLUMN_WIDTH}px stage cell; shorten it or split the journey"
        end
        width
      end

      def measured_lines(value, width, size, maximum, context, font: :sans)
        lines = Text.wrap(value, width, size, font: font)
        raise LayoutError, "#{context} does not fit its measured cell; shorten it" if lines.size > maximum
        lines
      end

      def ensure_tracked_fit!(value, width, size, context)
        raise LayoutError, "#{context} does not fit after tracking; shorten it" if tracked_width(value, size, :mono, 0.14) > width
      end

      def tracked_width(value, size, font, em)
        Text.width(value, size, font: font) + [value.each_char.count - 1, 0].max * size * em
      end
    end

    class StoryMap
      LEFT = 136
      COLUMN_WIDTH = 224
      GUTTER = 24
      BACKBONE_TOP = 32
      BACKBONE_HEIGHT = 56
      STEP_TOP = 100
      STEP_HEIGHT = 32
      STEP_GAP = 8
      RELEASE_TOP = 180
      STORY_HEIGHT = 48
      STORY_GAP = 8
      BAND_PADDING = 12
      RIGHT_PADDING = 16

      def initialize(diagram) = @d = diagram

      def call
        width = LEFT + @d.story_activities.size * COLUMN_WIDTH + (@d.story_activities.size - 1) * GUTTER + RIGHT_PADDING
        if @d.story_releases.sum { |release| release.stories.size } > 12
          raise LayoutError, 'Story-map limit is twelve stories; split the map without aggregation or reordering'
        end
        ensure_tracked_fit!("PERSONA · #{@d.persona}", width - LEFT, 12, 'Story-map persona')
        activities = []
        steps = []
        @d.story_activities.each_with_index do |activity, index|
          x = column_x(index)
          eyebrow = "ACTIVITY #{index + 1}"
          ensure_tracked_fit!(eyebrow, COLUMN_WIDTH - 20, 12, "Story-map activity eyebrow #{eyebrow.inspect}")
          lines = measured_lines(activity.label, COLUMN_WIDTH - 24, 14, 2, "Story-map activity label #{activity.label.inspect}")
          activities << { activity: activity, x: x, y: BACKBONE_TOP, width: COLUMN_WIDTH, height: BACKBONE_HEIGHT, eyebrow: eyebrow, lines: lines }
          activity.steps.each_with_index do |step, step_index|
            step_lines = measured_lines(step.label, COLUMN_WIDTH - 24, 14, 1, "Story-map step label #{step.label.inspect}")
            steps << { activity: activity, step: step, x: x + 8, y: STEP_TOP + step_index * (STEP_HEIGHT + STEP_GAP), width: COLUMN_WIDTH - 16, height: STEP_HEIGHT, lines: step_lines }
          end
        end

        releases = []
        stories = []
        cuts = []
        cursor = RELEASE_TOP
        @d.story_releases.each do |release|
          raise LayoutError, "Story-map release #{release.id} has more than four stories; split the release without aggregation or reordering" if release.stories.size > 4
          grouped = release.stories.group_by(&:activity)
          max_stack = grouped.values.map(&:size).max || 0
          height = BAND_PADDING * 2 + max_stack * STORY_HEIGHT + [max_stack - 1, 0].max * STORY_GAP
          ensure_tracked_fit!(release.label, LEFT - 20, 12, "Story-map release label #{release.label.inspect}")
          releases << { release: release, x: 0, y: cursor, width: width, height: height }
          @d.story_activities.each_with_index do |activity, activity_index|
            grouped.fetch(activity.id, []).each_with_index do |story, story_index|
              title_budget = story.risk ? COLUMN_WIDTH - 76 : COLUMN_WIDTH - 32
              lines = measured_lines(story.label, title_budget, 14, 2, "Story label #{story.label.inspect}")
              metadata = [story.ticket, story.estimate].compact.join(' · ')
              if !metadata.empty? && Text.width(metadata, 12, font: :mono) > COLUMN_WIDTH - 32
                raise LayoutError, "Story metadata #{metadata.inspect} does not fit its card; shorten it"
              end
              stories << {
                story: story, release: release, activity: activity,
                x: column_x(activity_index) + 8,
                y: cursor + BAND_PADDING + story_index * (STORY_HEIGHT + STORY_GAP),
                width: COLUMN_WIDTH - 16, height: STORY_HEIGHT, lines: lines, metadata: metadata
              }
            end
          end
          cursor += height
          if release.cut
            cuts << { release: release, y: cursor }
            cursor += 10
          end
        end
        gaps = @d.story_releases.any? do |release|
          activity_ids = release.stories.map(&:activity)
          @d.story_activities.any? { |activity| !activity_ids.include?(activity.id) }
        end
        guides = if gaps
          @d.story_activities.each_with_index.filter_map do |activity, index|
            next if index.zero?
            { activity: activity, x: column_x(index) - GUTTER / 2, y1: STEP_TOP + STEP_HEIGHT * 2 + STEP_GAP, y2: cursor }
          end
        else
          []
        end
        StoryMapScene.new(
          width: width, height: cursor + 68, persona: @d.persona, activities: activities, steps: steps,
          releases: releases, stories: stories, guides: guides, cuts: cuts, legend: { y: cursor + 18 }
        )
      end

      private

      def column_x(index) = LEFT + index * (COLUMN_WIDTH + GUTTER)

      def measured_lines(value, width, size, maximum, context)
        lines = Text.wrap(value, width, size)
        raise LayoutError, "#{context} does not fit its measured card; shorten it" if lines.size > maximum
        lines
      end

      def ensure_tracked_fit!(value, width, size, context)
        tracked = Text.width(value, size, font: :mono) + [value.each_char.count - 1, 0].max * size * 0.14
        raise LayoutError, "#{context} does not fit after tracking; shorten it" if tracked > width
      end
    end
  end
end
