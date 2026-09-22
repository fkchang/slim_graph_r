# frozen_string_literal: true

module SlimGraphR
  module Motion
    Target = Struct.new(:kind, :key, :label, keyword_init: true) do
      def self.node(value)
        id = Text.clean(value)
        new(kind: :node, key: "node:#{id.bytesize}:#{id}", label: id).freeze
      end

      def self.route(from, to)
        source, target = Text.clean(from), Text.clean(to)
        label = "route(#{source}, #{target})"
        new(kind: :route, key: "route:#{source.bytesize}:#{source}:#{target.bytesize}:#{target}", label: label).freeze
      end
    end

    Step = Struct.new(:number, :targets, :label, :replaces, keyword_init: true)

    class Storyboard
      MAX_STEPS = 12

      attr_reader :steps

      def self.build(&block)
        builder = new
        builder.instance_eval(&block) if block
        builder.finish
      end

      def initialize
        @steps = []
        @target_labels = {}
      end

      def route(from, to) = Target.route(from, to)

      def reveal(number, *values, replaces: [])
        label = values.pop
        raise Error, 'Motion step label must be a nonblank String' unless label.is_a?(String) && !label.strip.empty?
        targets = normalize_targets(values, 'target')
        replacement_values = replaces.is_a?(Array) ? replaces : [replaces]
        replaced = normalize_targets(replacement_values, 'replacement')
        raise Error, 'A motion step must reveal at least one target' if targets.empty?
        raise Error, 'A motion step cannot replace a target it reveals' unless (targets & replaced).empty?

        @steps << Step.new(number: number, targets: targets.freeze, label: Text.clean(label), replaces: replaced.freeze)
      end

      def finish
        raise Error, 'A storyboard requires at least one reveal step' if steps.empty?
        raise Error, "A storyboard allows at most #{MAX_STEPS} steps" if steps.size > MAX_STEPS
        numbers = steps.map(&:number)
        raise Error, 'Motion step numbers must be the contiguous sequence 1, 2, 3…' unless numbers == (1..steps.size).to_a
        targets = steps.flat_map(&:targets)
        duplicate = targets.group_by(&:itself).find { |_target, values| values.size > 1 }&.first
        raise Error, "Motion target #{duplicate.inspect} is revealed more than once" if duplicate
        unknown_replacement = steps.flat_map(&:replaces).find { |target| !targets.include?(target) }
        raise Error, "Motion replacement #{unknown_replacement.inspect} is never revealed" if unknown_replacement
        steps.each do |step|
          forward = step.replaces.find { |target| step_for(target).number >= step.number }
          raise Error, "Motion replacement #{forward.inspect} must be revealed before step #{step.number}" if forward
        end

        steps.each(&:freeze)
        steps.freeze
        @target_labels.freeze
        freeze
      end

      def step_for(target)
        steps.find { |step| step.targets.include?(target.to_s) }
      end

      def replaced_at(target)
        steps.find { |step| step.replaces.include?(target.to_s) }&.number
      end

      def targets = steps.flat_map(&:targets)

      def validate_rendered!(rendered)
        missing = targets - rendered
        return if missing.empty?
        labels = missing.map { |target| @target_labels.fetch(target, target) }
        raise Error, "Motion targets were not rendered: #{labels.join(', ')}. Use a node ID or route(:source, :target)."
      end

      private

      def normalize_targets(values, role)
        values.map do |value|
          target = value.is_a?(Target) ? value : Target.node(value)
          clean = target.label
          raise Error, "Motion #{role} must not be blank" if clean.strip.empty?
          if target.kind == :node && !clean.match?(/\A[a-zA-Z0-9_:-]+\z/)
            raise Error, "Motion #{role} #{clean.inspect} must contain only letters, digits, underscores, colons, or hyphens"
          end
          @target_labels[target.key] = target.label
          target.key
        end.uniq
      rescue NoMethodError
        raise Error, "Motion #{role}s must be node IDs or route(:source, :target)"
      end
    end

    class Presentation
      MODES = %i[steps reveal static].freeze
      attr_reader :diagram, :storyboard

      def self.build(diagram, &block) = new(diagram, Storyboard.build(&block))

      def initialize(diagram, storyboard)
        @diagram, @storyboard = diagram, storyboard
        freeze
      end

      def title = diagram.title
      def to_svg(id: nil)
        unless diagram.respond_to?(:to_motion_svg)
          raise Error, "Motion is not yet supported for #{diagram.class}; use a graph-backed diagram"
        end
        diagram.to_motion_svg(storyboard, id: id, static: true)
      end
      def with(**options) = self.class.new(diagram.with(**options), storyboard)

      def to_html(motion: :steps)
        mode = normalize_mode(motion)
        return MotionPlayer.static_document(self) if mode == :static

        MotionPlayer.document(self, mode: mode)
      end

      def fragment(mode: :steps, include_script: true)
        normalized = normalize_mode(mode)
        return to_svg if normalized == :static
        MotionPlayer.fragment(self, mode: normalized, include_script: include_script)
      end

      def motion_svg(id: nil)
        unless diagram.respond_to?(:to_motion_svg)
          raise Error, "Motion is not yet supported for #{diagram.class}; use a graph-backed diagram"
        end
        diagram.to_motion_svg(storyboard, id: id)
      end

      private

      def normalize_mode(value)
        mode = value.to_sym
        return mode if MODES.include?(mode)
        raise Error, "Motion mode must be :steps, :reveal, or :static"
      rescue NoMethodError
        raise Error, "Motion mode must be :steps, :reveal, or :static"
      end
    end
  end
end
