# frozen_string_literal: true
module SlimGraphR
  LoopHub = Struct.new(:id, :label, :sublabel, keyword_init: true)
  LoopStation = Struct.new(:id, :label, :sublabel, :focal, keyword_init: true)
  LoopWriteBack = Struct.new(:from, :to, :label, keyword_init: true)

  module LoopDSL
    attr_reader :loop_hub, :loop_stations, :loop_cycle, :loop_write_backs

    def initialize(...)
      @loop_hub = nil
      @loop_stations = []
      @loop_cycle = nil
      @loop_write_backs = []
      super
    end

    def hub(id, label, sublabel: nil)
      raise Error, 'hub is available only in a loop diagram' unless type == :loop
      raise Error, 'A loop requires exactly one hub' if @loop_hub
      @loop_hub = LoopHub.new(id: loop_text(id, 'Loop hub ID'), label: loop_text(label, 'Loop hub label'),
                              sublabel: loop_optional_text(sublabel, 'Loop hub sublabel'))
    end

    def station(id, label, sublabel: nil, focal: false)
      raise Error, 'station is available only in a loop diagram' unless type == :loop
      raise Error, 'Loop station focal must be true or false' unless [true, false].include?(focal)
      @loop_stations << LoopStation.new(id: loop_text(id, 'Loop station ID'), label: loop_text(label, 'Loop station label'),
                                       sublabel: loop_optional_text(sublabel, 'Loop station sublabel'), focal: focal)
    end

    def cycle(*ids)
      raise Error, 'cycle is available only in a loop diagram' unless type == :loop
      raise Error, 'A loop accepts exactly one explicit cycle declaration' if @loop_cycle
      raise Error, 'Loop cycle IDs must be passed as separate String or Symbol values' if ids.empty?
      @loop_cycle = ids.map { |id| loop_text(id, 'Loop cycle station ID') }
    end

    def write_back(source, to:, label: nil)
      raise Error, 'write_back is available only in a loop diagram' unless type == :loop
      sources = source.is_a?(Array) ? source : [source]
      raise Error, 'Loop write_back source list must not be empty' if sources.empty?
      clean_sources = sources.map { |id| loop_text(id, 'Loop write-back source ID') }
      destination = loop_text(to, 'Loop write-back destination ID')
      clean_label = loop_optional_text(label, 'Loop write-back label')
      @loop_write_backs.concat(clean_sources.map { |id| LoopWriteBack.new(from: id, to: destination, label: clean_label) })
    end

    def node(...)
      raise Error, 'Loop diagrams use dedicated hub, station, cycle, and write_back records' if type == :loop
      super
    end

    def edge(...)
      raise Error, 'Loop diagrams use dedicated hub, station, cycle, and write_back records' if type == :loop
      super
    end

    def flow(...)
      raise Error, 'Loop diagrams use dedicated hub, station, cycle, and write_back records' if type == :loop
      super
    end

    def group(...)
      raise Error, 'Loop diagrams use dedicated hub, station, cycle, and write_back records' if type == :loop
      super
    end

    private

    def loop_text(value, name)
      raise Error, "#{name} must be a String or Symbol" unless value.is_a?(String) || value.is_a?(Symbol)
      clean = Text.clean(value)
      raise Error, "#{name} must not be blank" if clean.strip.empty?
      clean
    end

    def loop_optional_text(value, name)
      return nil if value.nil?
      loop_text(value, name)
    end

    def validate_loop!
      unless nodes.empty? && edges.empty? && groups.empty? && events.empty? && rules.empty? && states.empty? &&
             transitions.empty? && zones.empty? && phases.empty? && crosscuts.empty?
        raise Error, 'Loop diagrams accept only dedicated hub, station, cycle, and write_back records'
      end
      raise Error, 'A loop requires exactly one hub' unless loop_hub
      raise Error, 'A loop requires five to eight stations' unless loop_stations.size.between?(5, 8)
      raise Error, 'Loop station IDs must be unique' unless loop_stations.map(&:id).uniq.size == loop_stations.size
      raise Error, 'Loop hub and station IDs must be distinct' if loop_stations.any? { |item| item.id == loop_hub.id }
      raise Error, 'A loop allows at most one focal station' if loop_stations.count(&:focal) > 1
      station_ids = loop_stations.map(&:id)
      unless loop_cycle && loop_cycle.size == station_ids.size && loop_cycle.uniq.size == loop_cycle.size && loop_cycle.sort == station_ids.sort
        raise Error, 'The explicit loop cycle must name every station exactly once'
      end
      unless loop_write_backs.size == station_ids.size && loop_write_backs.map(&:from).sort == station_ids.sort &&
             loop_write_backs.map(&:from).uniq.size == station_ids.size
        raise Error, 'A loop requires exactly one declared write-back per station'
      end
      unless loop_write_backs.all? { |item| item.to == loop_hub.id }
        raise Error, 'Every loop write-back destination must be the declared hub'
      end
      @loop_hub.freeze
      @loop_stations.each(&:freeze)
      @loop_stations.freeze
      @loop_cycle.freeze
      @loop_write_backs.each(&:freeze)
      @loop_write_backs.freeze
    end
  end
end

SlimGraphR::Diagram.prepend(SlimGraphR::LoopDSL)
