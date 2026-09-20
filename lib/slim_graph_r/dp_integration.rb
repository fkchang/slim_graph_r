# frozen_string_literal: true
module SlimGraphR
  IntegrationEndpoint = Struct.new(:id, :label, :kind, :detail, :side, keyword_init: true)
  IntegrationComponent = Struct.new(:id, :label, :role, :detail, :focal, :serves, :band_kind, keyword_init: true)
  IntegrationBand = Struct.new(:kind, :items, keyword_init: true)
  IntegrationPlatform = Struct.new(:label, :bands, keyword_init: true)
  IntegrationLayerService = Struct.new(:id, :label, :kind, :detail, :protocol, keyword_init: true)
  IntegrationWire = Struct.new(:from, :to, :kind, :protocol, keyword_init: true)

  module DPIntegrationDSL
    SOURCE_KINDS = %i[database file_drop mail legacy].freeze
    CONSUMER_KINDS = %i[analytics web api].freeze
    LAYER_SERVICE_KINDS = %i[identity observability backup secrets].freeze
    WIRE_KINDS = %i[ordinary federated trigger serve].freeze
    OPTION_UNSET = Object.new.freeze

    attr_reader :integration_sources, :integration_platform, :integration_consumers,
                :integration_layer_services, :integration_wires

    def initialize(...)
      @integration_sources = []
      @integration_consumers = []
      @integration_layer_services = []
      @integration_wires = []
      @integration_bands = []
      @integration_platform = nil
      @integration_scope = nil
      @integration_row_items = nil
      super
    end

    def source(id, label = OPTION_UNSET, kind: OPTION_UNSET, detail: nil, **options)
      unless type == :dp_integration
        options[:kind] = kind unless kind.equal?(OPTION_UNSET)
        options[:detail] = detail unless detail.nil?
        return label.equal?(OPTION_UNSET) ? super(id, **options) : super(id, label, **options)
      end
      integration_endpoint(:source, id, label, kind, detail, options)
    end

    def consumer(id, label = OPTION_UNSET, kind: OPTION_UNSET, detail: nil, **options)
      raise Error, 'consumer is available only in a DP integration diagram' unless type == :dp_integration
      integration_endpoint(:consumer, id, label, kind, detail, options)
    end

    def platform(label, **options, &block)
      raise Error, 'platform is available only in a DP integration diagram' unless type == :dp_integration
      raise Error, "Unknown integration platform options: #{options.keys.join(', ')}" unless options.empty?
      raise Error, 'A DP integration diagram accepts one platform' if @integration_platform || @integration_scope
      raise Error, 'platform requires a block' unless block
      clean_label = integration_text(label, 'Platform label')
      previous_scope = @integration_scope
      start = @integration_bands.length
      @integration_scope = :platform
      begin
        instance_eval(&block)
        bands = @integration_bands[start..].dup
        @integration_platform = IntegrationPlatform.new(label: clean_label, bands: bands)
      rescue Exception
        @integration_bands.slice!(start..)
        raise
      ensure
        @integration_scope = previous_scope
      end
      @integration_platform
    end

    def row(**options, &block)
      raise Error, 'row is available only inside a DP integration platform' unless type == :dp_integration && @integration_scope == :platform
      raise Error, "Unknown integration row options: #{options.keys.join(', ')}" unless options.empty?
      raise Error, 'row requires a block' unless block
      previous_scope = @integration_scope
      previous_items = @integration_row_items
      items = []
      @integration_scope = :row
      @integration_row_items = items
      begin
        instance_eval(&block)
        @integration_bands << IntegrationBand.new(kind: :row, items: items)
      ensure
        @integration_scope = previous_scope
        @integration_row_items = previous_items
      end
    end

    def bar(id, label = OPTION_UNSET, role: nil, detail: nil, focal: false, serves: false, **options)
      raise Error, 'bar is available only inside a DP integration platform' unless type == :dp_integration && @integration_scope == :platform
      item = integration_component(id, label, role, detail, focal, serves, options, :bar)
      @integration_bands << IntegrationBand.new(kind: :bar, items: [item])
      item
    end

    def service(id, label = OPTION_UNSET, role: nil, detail: nil, focal: false, serves: false, **options)
      raise Error, 'service is available only inside a DP integration row' unless type == :dp_integration && @integration_scope == :row
      item = integration_component(id, label, role, detail, focal, serves, options, :row)
      @integration_row_items << item
      item
    end

    def layer_service(id, label = OPTION_UNSET, kind: OPTION_UNSET, detail: nil, protocol: nil, **options)
      raise Error, 'layer_service is available only in a DP integration diagram' unless type == :dp_integration
      raise Error, "Unknown integration layer service options: #{options.keys.join(', ')}" unless options.empty?
      clean_kind = integration_enum(kind, LAYER_SERVICE_KINDS, 'Layer-service kind')
      clean_id, clean_label = integration_identity(id, label, 'Layer service')
      @integration_layer_services << IntegrationLayerService.new(
        id: clean_id, label: clean_label, kind: clean_kind,
        detail: integration_optional_text(detail, 'Layer-service detail'),
        protocol: integration_text(protocol, 'Layer-service protocol')
      )
    end

    def wire(from, to, kind: OPTION_UNSET, protocol: OPTION_UNSET, **options)
      raise Error, 'wire is available only in a DP integration diagram' unless type == :dp_integration
      raise Error, "Unknown integration wire options: #{options.keys.join(', ')}" unless options.empty?
      clean_kind = integration_enum(kind, WIRE_KINDS, 'Wire kind')
      if clean_kind == :trigger
        raise Error, 'Trigger wires are unlabelled and do not accept protocol' unless protocol.equal?(OPTION_UNSET)
        clean_protocol = nil
      else
        raise Error, 'A non-trigger integration wire requires protocol:' if protocol.equal?(OPTION_UNSET)
        clean_protocol = integration_text(protocol, 'Wire protocol')
      end
      @integration_wires << IntegrationWire.new(
        from: integration_text(from, 'Wire source ID'), to: integration_text(to, 'Wire target ID'),
        kind: clean_kind, protocol: clean_protocol
      )
    end

    def node(...)
      raise Error, 'DP integration diagrams use source, platform components, consumer, layer_service, and wire' if type == :dp_integration
      super
    end

    def edge(...)
      raise Error, 'DP integration diagrams use wire, not generic edge' if type == :dp_integration
      super
    end

    private

    def integration_endpoint(side, id, label, kind, detail, options)
      raise Error, "Unknown integration #{side} options: #{options.keys.join(', ')}" unless options.empty?
      allowed = side == :source ? SOURCE_KINDS : CONSUMER_KINDS
      clean_kind = integration_enum(kind, allowed, "#{side.to_s.capitalize} kind")
      clean_id, clean_label = integration_identity(id, label, side.to_s.capitalize)
      item = IntegrationEndpoint.new(id: clean_id, label: clean_label, kind: clean_kind,
                                     detail: integration_optional_text(detail, "#{side.to_s.capitalize} detail"), side: side)
      side == :source ? @integration_sources << item : @integration_consumers << item
      item
    end

    def integration_component(id, label, role, detail, focal, serves, options, band_kind)
      raise Error, "Unknown integration component options: #{options.keys.join(', ')}" unless options.empty?
      raise Error, 'focal must be true or false' unless [true, false].include?(focal)
      raise Error, 'serves must be true or false' unless [true, false].include?(serves)
      clean_id, clean_label = integration_identity(id, label, 'Platform component')
      IntegrationComponent.new(
        id: clean_id, label: clean_label, role: integration_optional_text(role, 'Component role'),
        detail: integration_optional_text(detail, 'Component detail'), focal: focal, serves: serves, band_kind: band_kind
      )
    end

    def integration_identity(id, label, kind)
      clean_id = integration_text(id, "#{kind} ID")
      value = label.equal?(OPTION_UNSET) ? id.to_s.tr('_', ' ').sub(/\A./, &:upcase) : label
      clean_label = integration_text(value, "#{kind} label")
      [clean_id, clean_label]
    end

    def integration_text(value, name)
      clean = value.nil? ? '' : Text.clean(value)
      raise Error, "#{name} is required and must not be blank" if clean.strip.empty?
      clean
    end

    def integration_optional_text(value, name)
      return nil if value.nil?
      integration_text(value, name)
    end

    def integration_enum(value, allowed, name)
      candidate = value.equal?(OPTION_UNSET) ? nil : value.to_s.to_sym
      raise Error, "#{name} must be one of #{allowed.join(', ')}" unless allowed.include?(candidate)
      candidate
    rescue NoMethodError
      raise Error, "#{name} must be one of #{allowed.join(', ')}"
    end

    def validate_dp_integration!
      unless nodes.empty? && edges.empty? && groups.empty? && events.empty? && rules.empty? && states.empty? &&
             transitions.empty? && zones.empty? && phases.empty? && crosscuts.empty?
        raise Error, 'DP integration diagrams accept only dedicated integration records'
      end
      raise Error, 'A DP integration diagram needs exactly one platform' unless integration_platform
      raise Error, 'DP integration diagrams allow zero to six sources' unless integration_sources.size.between?(0, 6)
      raise Error, 'DP integration diagrams allow zero to six consumers' unless integration_consumers.size.between?(0, 6)
      unless integration_sources.any? || integration_consumers.any?
        raise Error, 'A DP integration diagram needs at least one source or consumer'
      end
      rows = integration_platform.bands.select { |band| band.kind == :row }
      bars = integration_platform.bands.select { |band| band.kind == :bar }
      raise Error, 'A DP integration platform needs exactly one row' unless rows.one?
      raise Error, 'A DP integration platform allows zero to two bars' unless bars.size.between?(0, 2)
      raise Error, 'A DP integration row needs two to four services' unless rows.first.items.size.between?(2, 4)
      components = integration_platform.bands.flat_map(&:items)
      raise Error, 'A DP integration platform needs two to six components' unless components.size.between?(2, 6)
      raise Error, 'A DP integration diagram needs exactly two focal platform components' unless components.count(&:focal) == 2
      raise Error, 'A DP integration diagram needs exactly one serving component' unless components.count(&:serves) == 1
      raise Error, 'DP integration diagrams allow zero to three layer services' unless integration_layer_services.size.between?(0, 3)
      raise Error, 'A DP integration diagram needs at least one wire' if integration_wires.empty?
      raise Error, 'DP integration diagrams allow at most twenty wires' if integration_wires.size > 20

      all = integration_sources + components + integration_consumers + integration_layer_services
      raise Error, 'DP integration IDs must be globally unique' unless all.map(&:id).uniq.size == all.size
      if integration_wires.group_by { |item| [item.from, item.to] }.values.any? { |items| items.size > 1 }
        raise Error, 'Duplicate integration wires for one ordered endpoint pair are not supported'
      end
      endpoint_by_id = (integration_sources + components + integration_consumers).to_h { |item| [item.id, item] }
      source_ids = integration_sources.map(&:id)
      component_ids = components.map(&:id)
      consumer_ids = integration_consumers.map(&:id)
      serving = components.find(&:serves)
      integration_wires.each do |item|
        from = endpoint_by_id[item.from]
        to = endpoint_by_id[item.to]
        raise Error, "Unknown integration endpoint: #{item.from}" unless from
        raise Error, "Unknown integration endpoint: #{item.to}" unless to
        raise Error, 'An integration wire cannot connect an endpoint to itself' if item.from == item.to
        if item.kind == :serve
          unless component_ids.include?(item.from) && consumer_ids.include?(item.to)
            raise Error, 'A serve wire must connect a platform component to a consumer'
          end
          raise Error, 'A serve wire must originate at the one serving component' unless item.from == serving.id
        elsif item.kind == :trigger
          unless component_ids.include?(item.from) && component_ids.include?(item.to)
            raise Error, 'A trigger wire must stay inside the platform'
          end
          raise Error, 'A trigger wire must originate from a bar' unless from.band_kind == :bar
        elsif source_ids.include?(item.from)
          raise Error, 'A source wire must terminate at a platform component' unless component_ids.include?(item.to)
        elsif component_ids.include?(item.from) && component_ids.include?(item.to)
          raise Error, 'An internal wire originating from a bar must be an unlabelled trigger' if from.band_kind == :bar
        else
          raise Error, 'Ordinary and federated wires connect source to platform or platform to platform'
        end
      end

      integration_platform.bands.each do |band|
        band.items.each(&:freeze)
        band.items.freeze
        band.freeze
      end
      integration_platform.bands.freeze
      integration_platform.freeze
      [integration_sources, integration_consumers, integration_layer_services, integration_wires].each do |items|
        items.each(&:freeze)
        items.freeze
      end
    end
  end
end

SlimGraphR::Diagram.prepend(SlimGraphR::DPIntegrationDSL)
