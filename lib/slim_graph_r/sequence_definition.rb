# frozen_string_literal: true
module SlimGraphR
  Activation = Struct.new(:actor, :items, keyword_init: true)
  Fragment = Struct.new(:operator, :regions, keyword_init: true)
  Region = Struct.new(:guard, :items, keyword_init: true)

  # Keeps control structure as data; a loop is a description, never repeated execution.
  class SequenceDefinition
    attr_reader :items

    def initialize
      @items, @targets, @frames = [], [], []
      @targets << @items
      @frame = nil
    end

    def nested? = @targets.size > 1 || !@frame.nil?

    def append(item)
      raise Error, 'Place alt messages inside branch blocks' unless @targets.last
      @targets.last << item
    end

    def activation(actor)
      item = Activation.new(actor: actor, items: [])
      append(item)
      capture(item.items) { yield }
    end

    def fragment(operator, guard = nil)
      raise Error, 'Nested sequence frames are not supported; split the sequence' if @frame
      item = Fragment.new(operator: operator, regions: [])
      append(item)
      @frames << item
      @frame = item
      if operator == :alt
        capture(nil) { yield }
      else
        region = Region.new(guard: guard, items: [])
        item.regions << region
        capture(region.items) { yield }
      end
    ensure
      @frame = nil if @frame.equal?(item)
    end

    def branch(guard)
      raise Error, 'branch belongs directly inside alt' unless @frame&.operator == :alt && @targets.last.nil?
      region = Region.new(guard: guard, items: [])
      @frame.regions << region
      capture(region.items) { yield }
    end

    def finish!(nodes)
      if @frames.size > 2 || (@frames.size == 2 && @frames.any? { |f| f.operator == :alt })
        raise Error, 'Use one alt frame, or at most two opt/loop frames; split the sequence'
      end
      @frames.each do |frame|
        if frame.operator == :alt && frame.regions.size != 2
          raise Error, 'alt needs exactly two branch blocks'
        end
      end
      validate_and_freeze(items, nodes.map(&:id), Hash.new(0))
      freeze
    end

    private

    def capture(target)
      @targets << target
      yield
    ensure
      @targets.pop
    end

    def validate_and_freeze(list, actors, depth)
      list.each do |item|
        case item
        when Activation
          raise Error, "Unknown activation participant: #{item.actor}" unless actors.include?(item.actor)
          raise Error, 'An activation block must contain a message' if message_ids(item.items).empty?
          depth[item.actor] += 1
          raise Error, "Activation nesting for #{item.actor} exceeds three levels" if depth[item.actor] > 3
          validate_and_freeze(item.items, actors, depth)
          depth[item.actor] -= 1
        when Fragment
          item.regions.each do |region|
            raise Error, 'Each sequence region needs at least one message' if message_ids(region.items).empty?
            validate_and_freeze(region.items, actors, depth)
            region.freeze
          end
          item.regions.freeze
        end
        item.freeze
      end
      list.freeze
    end

    def message_ids(list)
      list.flat_map do |item|
        case item
        when Edge then [item.from, item.to]
        when Activation then message_ids(item.items)
        when Fragment then item.regions.flat_map { |region| message_ids(region.items) }
        end
      end
    end
  end
end
