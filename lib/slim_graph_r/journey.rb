# frozen_string_literal: true
module SlimGraphR
  JourneyStage = Struct.new(:id, :label, :action, :touchpoint, :sentiment, :pains, keyword_init: true)
  StoryStep = Struct.new(:id, :label, keyword_init: true)
  StoryActivity = Struct.new(:id, :label, :steps, keyword_init: true)
  StoryCard = Struct.new(:id, :label, :activity, :estimate, :ticket, :risk, keyword_init: true)
  StoryRelease = Struct.new(:id, :label, :cut, :stories, keyword_init: true)

  class Diagram
    JOURNEY_SENTIMENTS = %i[high medium_high neutral medium_low low].freeze
    JOURNEY_SENTIMENT_RANK = JOURNEY_SENTIMENTS.each_with_index.to_h.freeze
    JOURNEY_UNSET = Object.new.freeze

    alias journey_original_stage stage unless method_defined?(:journey_original_stage)
    alias journey_original_activity activity unless method_defined?(:journey_original_activity)
    alias journey_original_step step unless method_defined?(:journey_original_step)

    def stage(id, label = nil, sentiment: JOURNEY_UNSET, focal: WORKFLOW_UNSET, **options, &block)
      previous = @current_journey_stage if type == :journey
      unless type == :journey
        raise Error, "Stage does not accept: #{options.keys.join(', ')}" unless options.empty?
        raise Error, 'sentiment is available only in a journey diagram' unless sentiment.equal?(JOURNEY_UNSET)
        return journey_original_stage(id, label, focal: focal, &block)
      end
      raise Error, "Journey stage does not accept: #{options.keys.join(', ')}" unless options.empty?
      raise Error, 'Journey stages do not accept focal styling' unless focal.equal?(WORKFLOW_UNSET)
      raise Error, 'A journey stage requires a block' unless block
      raise Error, 'Journey stages cannot nest' if @current_journey_stage
      clean_id, clean_label = journey_identity(id, label, 'Journey stage')
      clean_sentiment = journey_sentiment(sentiment)
      item = JourneyStage.new(id: clean_id, label: clean_label, sentiment: clean_sentiment, pains: [])
      @journey_stages << item
      @current_journey_stage = item
      instance_eval(&block)
      item
    ensure
      @current_journey_stage = previous if type == :journey
    end

    def action(value)
      raise Error, 'action is available only inside a journey stage' unless type == :journey && @current_journey_stage
      raise Error, "Journey stage #{@current_journey_stage.id} already has an action" if @current_journey_stage.action
      @current_journey_stage.action = journey_text(value, 'Journey action')
    end

    def touchpoint(value)
      raise Error, 'touchpoint is available only inside a journey stage' unless type == :journey && @current_journey_stage
      raise Error, "Journey stage #{@current_journey_stage.id} already has a touchpoint" if @current_journey_stage.touchpoint
      @current_journey_stage.touchpoint = journey_text(value, 'Journey touchpoint')
    end

    def pain(value)
      raise Error, 'pain is available only inside a journey stage' unless type == :journey && @current_journey_stage
      raise Error, 'A journey stage allows at most two pain markers' if @current_journey_stage.pains.size >= 2
      @current_journey_stage.pains << journey_text(value, 'Journey pain')
    end

    def activity(id, label = nil, lane: JOURNEY_UNSET, stage: JOURNEY_UNSET, detail: JOURNEY_UNSET, focal: WORKFLOW_UNSET, **options, &block)
      previous = @current_story_activity if type == :story_map
      unless type == :story_map
        raise Error, "Activity does not accept: #{options.keys.join(', ')}" unless options.empty?
        workflow_options = { lane: lane, stage: stage, focal: focal }
        workflow_options[:detail] = detail unless detail.equal?(JOURNEY_UNSET)
        return journey_original_activity(id, label, **workflow_options, &block)
      end
      supplied = { lane: lane, stage: stage, detail: detail, focal: focal }.reject { |_key, value| value.equal?(JOURNEY_UNSET) || value.equal?(WORKFLOW_UNSET) }
      supplied.merge!(options)
      raise Error, "Story-map activity does not accept: #{supplied.keys.join(', ')}" unless supplied.empty?
      raise Error, 'A story-map activity cannot be declared inside a release; close the release first' if @current_story_release
      raise Error, 'A story-map activity requires a block' unless block
      raise Error, 'Story-map activities cannot nest' if @current_story_activity
      clean_id, clean_label = journey_identity(id, label, 'Story-map activity')
      item = StoryActivity.new(id: clean_id, label: clean_label, steps: [])
      @story_activities << item
      @current_story_activity = item
      instance_eval(&block)
      item
    ensure
      @current_story_activity = previous if type == :story_map
    end

    def step(id, label = nil, **options)
      return journey_original_step(id, label, **options) unless type == :story_map
      raise Error, "Story-map step does not accept: #{options.keys.join(', ')}" unless options.empty?
      raise Error, 'Declare a story-map step inside an activity' unless @current_story_activity
      clean_id, clean_label = journey_identity(id, label, 'Story-map step')
      @current_story_activity.steps << StoryStep.new(id: clean_id, label: clean_label)
    end

    def release(id, label = nil, cut: false, **options, &block)
      previous = @current_story_release if type == :story_map
      raise Error, 'release is available only in a story-map diagram' unless type == :story_map
      raise Error, "Story-map release does not accept: #{options.keys.join(', ')}" unless options.empty?
      raise Error, 'A story-map release cannot be declared inside an activity; close the activity first' if @current_story_activity
      raise Error, 'Story-map release cut must be true or false' unless [true, false].include?(cut)
      raise Error, 'A story-map release requires a block' unless block
      raise Error, 'Story-map releases cannot nest' if @current_story_release
      clean_id, clean_label = journey_identity(id, label, 'Story-map release')
      item = StoryRelease.new(id: clean_id, label: clean_label, cut: cut, stories: [])
      @story_releases << item
      @current_story_release = item
      instance_eval(&block)
      item
    ensure
      @current_story_release = previous if type == :story_map
    end

    def story(id, label = nil, activity:, estimate: nil, ticket: nil, risk: false, **options)
      raise Error, 'story is available only in a story-map diagram' unless type == :story_map
      raise Error, "Story-map story does not accept: #{options.keys.join(', ')}" unless options.empty?
      raise Error, 'Declare a story inside a release' unless @current_story_release
      raise Error, 'Story risk must be true or false' unless [true, false].include?(risk)
      clean_id, clean_label = journey_identity(id, label, 'Story-map story')
      @current_story_release.stories << StoryCard.new(
        id: clean_id, label: clean_label, activity: journey_reference(activity, 'Story activity'),
        estimate: journey_optional_text(estimate, 'Story estimate'),
        ticket: journey_optional_text(ticket, 'Story ticket'), risk: risk
      )
    end

    private

    def journey_identity(id, label, kind)
      clean_id = Text.clean(id)
      clean_label = Text.clean(label || clean_id.tr('_-', ' ').split.map(&:capitalize).join(' '))
      raise Error, "#{kind} ID must not be blank" if clean_id.strip.empty?
      raise Error, "#{kind} label must not be blank" if clean_label.strip.empty?
      [clean_id, clean_label]
    rescue NoMethodError, TypeError
      raise Error, "#{kind} ID and label must be strings or symbols"
    end

    def journey_text(value, kind)
      clean = Text.clean(value)
      raise Error, "#{kind} must not be blank" if clean.strip.empty?
      clean
    rescue NoMethodError, TypeError
      raise Error, "#{kind} must be a nonblank string"
    end

    def journey_optional_text(value, kind)
      return nil if value.nil?
      journey_text(value, kind)
    end

    def journey_reference(value, kind) = journey_text(value, kind)

    def journey_sentiment(value)
      sentiment = value.to_sym unless value.equal?(JOURNEY_UNSET)
      unless JOURNEY_SENTIMENTS.include?(sentiment)
        raise Error, "Journey ordinal sentiment must be one of #{JOURNEY_SENTIMENTS.join(', ')}"
      end
      sentiment
    rescue NoMethodError
      raise Error, "Journey ordinal sentiment must be one of #{JOURNEY_SENTIMENTS.join(', ')}"
    end

    def validate_journey!
      raise Error, 'Journey diagrams use fixed horizontal stage order and do not accept direction' unless direction == :down
      raise Error, 'Journey diagrams do not accept nodes, edges, groups, or timeline events' unless nodes.empty? && edges.empty? && groups.empty? && events.empty?
      raise Error, 'Journey diagrams need two to six stages' unless journey_stages.size.between?(2, 6)
      raise Error, 'Journey stage IDs must be unique' unless journey_stages.map(&:id).uniq.size == journey_stages.size
      journey_stages.each do |item|
        raise Error, "Journey stage #{item.id} requires exactly one action" unless item.action
      end
      lowest_rank = journey_stages.map { |item| JOURNEY_SENTIMENT_RANK.fetch(item.sentiment) }.max
      troughs = journey_stages.select { |item| JOURNEY_SENTIMENT_RANK.fetch(item.sentiment) == lowest_rank }
      unless troughs.one?
        raise Error, 'Journey diagrams require one unique lowest-sentiment trough; tied lowest values are not changed or tie-broken'
      end
      journey_stages.each do |item|
        next if item.pains.empty? || item.equal?(troughs.first)
        raise Error, "Journey pain markers are allowed only on the unique trough stage #{troughs.first.id}"
      end
      raise Error, 'Journey diagrams allow at most two pain markers' if journey_stages.sum { |item| item.pains.size } > 2
    end

    def validate_story_map!
      raise Error, 'Story maps use fixed narrative order and do not accept direction' unless direction == :down
      raise Error, 'Story maps do not accept nodes, edges, groups, or timeline events' unless nodes.empty? && edges.empty? && groups.empty? && events.empty?
      raise Error, 'Story maps need two to five activities' unless story_activities.size.between?(2, 5)
      raise Error, 'Story maps need two to three releases' unless story_releases.size.between?(2, 3)
      story_activities.each do |item|
        unless item.steps.size.between?(1, 2)
          raise Error, "Story-map activity #{item.id} needs one or two steps"
        end
      end
      all_ids = story_activities.map(&:id) + story_activities.flat_map { |item| item.steps.map(&:id) } +
                story_releases.map(&:id) + story_releases.flat_map { |item| item.stories.map(&:id) }
      raise Error, 'Story-map activity, step, release, and story IDs must be unique' unless all_ids.uniq.size == all_ids.size
      raise Error, 'Every story-map release needs at least one story' if story_releases.any? { |item| item.stories.empty? }
      cuts = story_releases.each_index.select { |index| story_releases[index].cut }
      raise Error, 'A story map requires exactly one explicit release cut' unless cuts.one?
      raise Error, 'The story-map release cut cannot be on the last release' if cuts.first == story_releases.size - 1
      stories = story_releases.flat_map(&:stories)
      raise Error, 'A story map allows at most one risk story' if stories.count(&:risk) > 1
      activity_ids = story_activities.map(&:id)
      stories.each do |item|
        raise Error, "Unknown activity in story map: #{item.activity}" unless activity_ids.include?(item.activity)
      end
    end
  end
end
