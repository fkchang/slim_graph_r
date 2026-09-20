# frozen_string_literal: true
module SlimGraphR
  VennSet = Struct.new(:id, :label, :subtitle, keyword_init: true)
  VennIntersection = Struct.new(:sets, :label, :focal, keyword_init: true)

  module VennDSL
    attr_reader :venn_sets, :intersections

    def initialize(...)
      @venn_sets = []
      @intersections = []
      super
    end

    def set(id, label, subtitle: nil)
      raise Error, 'set is available only in a Venn diagram' unless type == :venn
      clean_subtitle = subtitle.nil? ? nil : venn_text(subtitle, 'Venn set subtitle')
      @venn_sets << VennSet.new(id: venn_text(id, 'Venn set ID'), label: venn_text(label, 'Venn set label'), subtitle: clean_subtitle)
    end

    def intersection(members, label, focal: false)
      raise Error, 'intersection is available only in a Venn diagram' unless type == :venn
      raise Error, 'Venn intersection focal must be true or false' unless [true, false].include?(focal)
      raise Error, 'Venn intersection sets must be an array of two or three IDs' unless members.is_a?(Array) && members.size.between?(2, 3)
      ids = members.map { |member| venn_text(member, 'Venn intersection set ID') }
      raise Error, 'Venn intersection members must be distinct' unless ids.uniq.size == ids.size
      @intersections << VennIntersection.new(sets: ids.freeze, label: venn_text(label, 'Venn intersection label'), focal: focal)
    end

    def node(...)
      raise Error, 'Venn diagrams use dedicated set and intersection records' if type == :venn
      super
    end

    def edge(...)
      raise Error, 'Venn diagrams use dedicated set and intersection records' if type == :venn
      super
    end

    def flow(...)
      raise Error, 'Venn diagrams use dedicated set and intersection records' if type == :venn
      super
    end

    def group(...)
      raise Error, 'Venn diagrams use dedicated set and intersection records' if type == :venn
      super
    end

    private

    def venn_text(value, name)
      raise Error, "#{name} must be a String or Symbol" unless value.is_a?(String) || value.is_a?(Symbol)
      clean = Text.clean(value)
      raise Error, "#{name} must not be blank" if clean.strip.empty?
      clean
    end

    def validate_venn!
      unless nodes.empty? && edges.empty? && groups.empty? && events.empty? && rules.empty? && states.empty? &&
             transitions.empty? && zones.empty? && phases.empty? && crosscuts.empty?
        raise Error, 'Venn diagrams accept only dedicated set and intersection records'
      end
      raise Error, 'A Venn diagram requires exactly two or three sets' unless venn_sets.size.between?(2, 3)
      raise Error, 'Venn set IDs must be unique' unless venn_sets.map(&:id).uniq.size == venn_sets.size
      known = venn_sets.map(&:id)
      intersections.each do |item|
        unknown = item.sets - known
        raise Error, "Venn intersection references unknown set: #{unknown.join(', ')}" unless unknown.empty?
      end
      keys = intersections.map { |item| item.sets.sort }
      raise Error, 'Venn intersections contain duplicate topology' unless keys.uniq.size == keys.size
      expected = if known.size == 2
        [known.sort]
      else
        known.combination(2).map(&:sort) + [known.sort]
      end
      missing = expected - keys
      extra = keys - expected
      unless missing.empty? && extra.empty? && intersections.size == expected.size
        detail = missing.empty? ? '' : "; missing #{missing.map { |ids| ids.join(' + ') }.join(', ')}"
        requirement = known.size == 2 ? 'the sole pair exactly once' : 'every pair and the triple exactly once'
        raise Error, "A Venn diagram must name #{requirement}#{detail}"
      end
      raise Error, 'A Venn diagram allows at most one focal overlap' if intersections.count(&:focal) > 1
      venn_sets.each(&:freeze)
      venn_sets.freeze
      intersections.each(&:freeze)
      intersections.freeze
    end
  end
end

SlimGraphR::Diagram.prepend(SlimGraphR::VennDSL)
