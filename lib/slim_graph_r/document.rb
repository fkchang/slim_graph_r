# frozen_string_literal: true
require 'json'
require_relative '../slim_graph_r'

module SlimGraphR
  # JSON is data, never Ruby source. Unknown fields are errors rather than silent omissions.
  class Document
    MAX_BYTES = 1_048_576
    TOP_KEYS = %w[type title description direction theme style scale subtitle eyebrow cluster axis indicator orientation mode unit source_note precision notation balance x_unit y_unit x_axis x_scale y_scale points series levels tiers promotions write_paths root scope layers nodes edges groups events roles components permissions entities relationships tables foreign_keys classes relations horizontal_axis vertical_axis items regions sets intersections hub stations cycle write_backs effect categories criteria dependencies steps transfers flows escalations approvals setup_gaps states initial finals transitions zones paths phases milestones markers columns handoffs crosscuts connections orchestration lanes stages activities operations trigger persona releases sources platform consumers layer_services wires].freeze
    COMMON_KEYS = %w[type title description direction theme style scale].freeze
    HIERARCHY_KEYS = %w[axis indicator root scope layers].freeze

    def self.from_json(source)
      raise Error, 'Input must be a String containing UTF-8 JSON' unless source.is_a?(String)
      raise Error, 'Input exceeds the 1 MiB document limit' if source.bytesize > MAX_BYTES
      source = source.dup.force_encoding(Encoding::UTF_8)
      raise Error, 'Input must be valid UTF-8' unless source.valid_encoding?
      new(JSON.parse(source)).diagram
    rescue JSON::ParserError => e
      raise Error, "Invalid JSON: #{e.message}"
    end

    def initialize(data)
      @data = object(data, TOP_KEYS, 'document')
    end

    def diagram
      type = string(@data, 'type', required: true).to_sym
      return quantitative_diagram(type) if %i[bar line scatter treemap sankey polar radar].include?(type)
      quantitative_fields = @data.keys & %w[source_note precision notation balance x_unit y_unit x_axis x_scale y_scale points series flows]
      unless quantitative_fields.empty?
        raise Error, "Only quantitative charts accept: #{quantitative_fields.join(', ')}"
      end
      options = %w[title description direction theme style scale subtitle eyebrow cluster].each_with_object({}) do |key, result|
        next unless @data.key?(key)
        value = string(@data, key)
        result[key.to_sym] = %w[direction theme style scale].include?(key) ? value.to_sym : value
      end
      if type == :layers
        options[:axis] = string(@data, 'axis') if @data.key?('axis')
        options[:indicator] = string(@data, 'indicator').to_sym if @data.key?('indicator')
      end
      if type == :pyramid
        options[:orientation] = string(@data, 'orientation').to_sym if @data.key?('orientation')
        options[:mode] = string(@data, 'mode').to_sym if @data.key?('mode')
        options[:unit] = string(@data, 'unit') if @data.key?('unit')
      end
      options[:persona] = string(@data, 'persona', required: true) if %i[journey story_map].include?(type)
      return dp_integration_diagram(options) if type == :dp_integration
      return dp_security_matrix_diagram(options) if type == :dp_security_matrix
      return er_diagram(options) if type == :er
      return db_schema_diagram(options) if type == :db_schema
      return uml_class_diagram(options) if type == :uml_class
      return quadrant_diagram(options) if type == :quadrant
      return venn_diagram(options) if type == :venn
      return loop_diagram(options) if type == :loop
      return fishbone_diagram(options) if type == :fishbone
      return wardley_diagram(options) if type == :wardley
      return data_flow_diagram(options) if type == :data_flow
      return state_diagram(options) if type == :state
      return dependency_diagram(options) if type == :dependency
      return deployment_diagram(options) if type == :deployment
      return high_level_diagram(options) if type == :high_level
      return it_state_diagram(options) if type == :it_state
      return workflow_diagram(type, options) if %i[swimlane process].include?(type)
      return gantt_diagram(options) if type == :gantt
      return kanban_diagram(options) if type == :kanban
      return journey_diagram(options) if type == :journey
      return story_map_diagram(options) if type == :story_map
      return tree_diagram(options) if type == :tree
      return nested_diagram(options) if type == :nested
      return layers_diagram(options) if type == :layers
      return pyramid_diagram(options) if type == :pyramid
      return medallion_diagram(options) if type == :medallion
      data_flow_fields = @data.keys & %w[roles transfers]
      unless data_flow_fields.empty?
        raise Error, "Only a data-flow diagram accepts: #{data_flow_fields.join(', ')}"
      end
      security_matrix_fields = @data.keys & %w[components permissions]
      unless security_matrix_fields.empty?
        raise Error, "Only a DP security matrix accepts: #{security_matrix_fields.join(', ')}"
      end
      er_fields = @data.keys & %w[entities relationships]
      unless er_fields.empty?
        raise Error, "Only an ER diagram accepts: #{er_fields.join(', ')}"
      end
      database_fields = @data.keys & %w[tables foreign_keys]
      unless database_fields.empty?
        raise Error, "Only a database-schema diagram accepts: #{database_fields.join(', ')}"
      end
      uml_fields = @data.keys & %w[classes relations]
      unless uml_fields.empty?
        raise Error, "Only a UML class diagram accepts: #{uml_fields.join(', ')}"
      end
      quadrant_fields = @data.keys & %w[horizontal_axis vertical_axis items regions]
      unless quadrant_fields.empty?
        raise Error, "Only a quadrant diagram accepts: #{quadrant_fields.join(', ')}"
      end
      venn_fields = @data.keys & %w[sets intersections]
      unless venn_fields.empty?
        raise Error, "Only a Venn diagram accepts: #{venn_fields.join(', ')}"
      end
      loop_fields = @data.keys & %w[hub stations cycle write_backs]
      unless loop_fields.empty?
        raise Error, "Only a loop diagram accepts: #{loop_fields.join(', ')}"
      end
      fishbone_fields = @data.keys & %w[effect categories]
      unless fishbone_fields.empty?
        raise Error, "Only a fishbone diagram accepts: #{fishbone_fields.join(', ')}"
      end
      wardley_fields = @data.keys & %w[dependencies]
      unless wardley_fields.empty?
        raise Error, "Only a Wardley map accepts: #{wardley_fields.join(', ')}"
      end
      journey_fields = @data.keys & %w[persona releases]
      unless journey_fields.empty?
        raise Error, "Only journey and story-map diagrams accept: #{journey_fields.join(', ')}"
      end
      family_fields = @data.keys & %w[orientation mode unit levels tiers promotions write_paths]
      unless family_fields.empty?
        raise Error, "Only pyramid and medallion diagrams accept: #{family_fields.join(', ')}"
      end
      hierarchy_fields = @data.keys & HIERARCHY_KEYS
      unless hierarchy_fields.empty?
        raise Error, "Only tree, nested-containment, and layer-stack diagrams accept: #{hierarchy_fields.join(', ')}"
      end
      high_level_fields = @data.keys & %w[cluster connections orchestration]
      unless high_level_fields.empty?
        raise Error, "Only a high-level diagram accepts: #{high_level_fields.join(', ')}"
      end
      placement_fields = @data.keys & %w[zones paths]
      unless placement_fields.empty?
        raise Error, "Only a deployment diagram accepts: #{placement_fields.join(', ')}"
      end
      landscape_fields = @data.keys & %w[phases handoffs crosscuts]
      unless landscape_fields.empty?
        raise Error, "Only high-level and IT current-state diagrams accept: #{landscape_fields.join(', ')}"
      end
      if (@data.keys & %w[states initial finals transitions]).any?
        raise Error, 'Only a state machine accepts states, initial, finals, and transitions'
      end
      nodes = records('nodes', %w[id label detail kind emphasis group invoke scope unavailable], 32)
      groups = records('groups', %w[id label], 3)
      edges = records('edges', %w[from to label dashed kind], 64)
      events = records('events', %w[date label detail emphasis], 32)
      escalations = records('escalations', %w[label to], 2)
      approvals = records('approvals', %w[label by], 2)
      setup_gaps = records('setup_gaps', %w[label for], 3)
      if @data.key?('steps')
        raise Error, 'Only a sequence accepts steps' unless type == :sequence
        raise Error, 'Use either sequence steps or edges, not both' if @data.key?('edges')
      end
      @action_count = 0
      actions = @data.key?('steps') ? sequence_steps(@data['steps']) : nil
      reader = self
      raise Error, 'A timeline accepts events, not nodes/edges/groups' if type == :timeline && [nodes, edges, groups].any? { |v| !v.empty? }
      raise Error, 'Only a timeline accepts events' if type != :timeline && !events.empty?
      if type != :org_chart
        if nodes.any? { |node| (node.keys & %w[invoke scope unavailable]).any? }
          raise Error, 'invoke, scope, and unavailable are only valid for org_chart nodes'
        end
        if @data.key?('escalations') || @data.key?('approvals') || @data.key?('setup_gaps')
          raise Error, 'escalations, approvals, and setup_gaps are only valid for org_chart'
        end
      end
      groups.each { |g| string(g, 'id', required: true); string(g, 'label') }
      group_ids = groups.map { |g| g['id'] }
      nodes.each do |n|
        %w[id label detail kind group].each { |k| string(n, k, required: k == 'id') }
        boolean(n, 'emphasis')
        %w[invoke scope].each { |k| string(n, k) }
        boolean(n, 'unavailable')
        raise Error, "Unknown group: #{n['group']}" if n.key?('group') && !group_ids.include?(n['group'])
      end
      edges.each { |e| %w[from to label kind].each { |k| string(e, k, required: %w[from to].include?(k)) }; boolean(e, 'dashed') }
      events.each { |e| %w[date label detail].each { |k| string(e, k, required: k != 'detail') }; boolean(e, 'emphasis') }
      escalations.each { |rule| %w[label to].each { |key| string(rule, key, required: true) } }
      approvals.each { |rule| %w[label by].each { |key| string(rule, key, required: true) } }
      setup_gaps.each { |gap| %w[label for].each { |key| string(gap, key, required: true) } }
      SlimGraphR.diagram(type, **options) do
        add_node = lambda do |n|
          node_options = { detail: n['detail'], kind: n.fetch('kind', 'service').to_sym, emphasis: n.fetch('emphasis', false) }
          if type == :org_chart
            node_options.merge!(invoke: n['invoke'], scope: n['scope'], unavailable: n.fetch('unavailable', false))
          end
          node n.fetch('id'), n['label'], **node_options
        end
        nodes.reject { |n| n.key?('group') }.each(&add_node)
        groups.each do |g|
          group(g.fetch('id'), g['label']) { nodes.select { |n| n['group'] == g['id'] }.each(&add_node) }
        end
        edges.each { |e| edge e.fetch('from'), e.fetch('to'), e['label'], dashed: e['dashed'], kind: e['kind'] }
        escalations.each { |rule| escalation rule.fetch('label'), to: rule.fetch('to') }
        approvals.each { |rule| approval rule.fetch('label'), by: rule.fetch('by') }
        setup_gaps.each { |gap| setup_gap gap.fetch('label'), for: gap.fetch('for') }
        reader.apply_sequence(self, actions) if actions
        events.each { |e| event e.fetch('date'), e.fetch('label'), detail: e['detail'], emphasis: e.fetch('emphasis', false) }
      end
    end

    def apply_sequence(builder, actions)
      reader = self
      actions.each do |action|
        case action[:type]
        when :message
          edge = action[:message]
          builder.message(edge['from'], edge['to'], edge['label'], kind: edge['kind'], dashed: edge['dashed'])
        when :activate
          builder.activate(action[:actor]) { reader.apply_sequence(builder, action[:steps]) }
        when :alt
          builder.alt do
            action[:regions].each do |region|
              builder.branch(region[:guard]) { reader.apply_sequence(builder, region[:steps]) }
            end
          end
        when :opt
          builder.opt(action[:guard]) { reader.apply_sequence(builder, action[:steps]) }
        when :loop
          builder.loop(action[:guard]) { reader.apply_sequence(builder, action[:steps]) }
        end
      end
    end

    private

    def quantitative_diagram(type)
      root_keys = %w[type title description style theme source_note precision notation]
      extras = case type
               when :bar then %w[unit orientation scale categories]
               when :line then %w[unit x_axis scale series]
               when :scatter then %w[x_unit y_unit x_scale y_scale points]
               when :treemap then %w[unit items]
               when :sankey then %w[unit balance stages nodes flows]
               when :polar then %w[unit scale categories]
               when :radar then %w[unit scale criteria entities]
               end
      object(@data, root_keys + extras, "#{type} document")
      options = {}
      %w[title description style theme source_note].each do |key|
        next unless @data.key?(key)
        value = string(@data, key, required: true)
        options[key.to_sym] = %w[style theme].include?(key) ? value.to_sym : value
      end
      options[:precision] = integer(@data, 'precision', minimum: 0, maximum: 6) if @data.key?('precision')
      if @data.key?('notation')
        options[:notation] = string(@data, 'notation', required: true).to_sym
      end
      case type
      when :polar
        options[:unit] = string(@data, 'unit', required: true)
        scale = quantitative_scale('scale', required: true)
        categories = quantitative_records('categories', %w[id label value focal], required: true)
        categories.each do |item|
          %w[id label].each { |key| string(item, key, required: true) }
          item['value'] = quantitative_number(item, 'value')
          boolean(item, 'focal')
        end
        SlimGraphR.diagram(:polar, **options) do
          scale(**scale)
          categories.each { |item| category(item.fetch('id'), item.fetch('label'), item.fetch('value'), focal: item.fetch('focal', false)) }
        end
      when :radar
        options[:unit] = string(@data, 'unit', required: true)
        scale = quantitative_scale('scale', required: true)
        criteria = quantitative_records('criteria', %w[id label], required: true)
        criteria.each { |item| %w[id label].each { |key| string(item, key, required: true) } }
        criterion_ids = criteria.map { |item| item.fetch('id') }
        entities = quantitative_records('entities', %w[id label values focal], required: true)
        entities.each do |item|
          %w[id label].each { |key| string(item, key, required: true) }
          boolean(item, 'focal')
          raw_values = object(item.fetch('values') { raise Error, 'Missing required field: values' }, criterion_ids, 'entity values')
          unless raw_values.keys.sort == criterion_ids.sort
            raise Error, 'Radar entity values must contain exactly the declared criterion IDs'
          end
          item['values'] = criterion_ids.to_h do |criterion_id|
            [criterion_id, Quantitative::Value.json_number(raw_values.fetch(criterion_id), "value for #{criterion_id}")]
          end
        end
        SlimGraphR.diagram(:radar, **options) do
          scale(**scale)
          criteria.each { |item| criterion(item.fetch('id'), item.fetch('label')) }
          entities.each { |item| entity(item.fetch('id'), item.fetch('label'), values: item.fetch('values'), focal: item.fetch('focal', false)) }
        end
      when :bar
        options[:unit] = string(@data, 'unit', required: true)
        options[:orientation] = string(@data, 'orientation', required: true).to_sym if @data.key?('orientation')
        scale = quantitative_scale('scale', required: false)
        categories = quantitative_records('categories', %w[id label value focal], required: true)
        categories.each do |item|
          %w[id label].each { |key| string(item, key, required: true) }
          item['value'] = quantitative_number(item, 'value')
          boolean(item, 'focal')
        end
        SlimGraphR.diagram(:bar, **options) do
          scale(**scale) if scale
          categories.each { |item| category(item.fetch('id'), item.fetch('label'), item.fetch('value'), focal: item.fetch('focal', false)) }
        end
      when :line
        options[:unit] = string(@data, 'unit', required: true)
        scale = quantitative_scale('scale', required: false)
        axis = object(@data.fetch('x_axis') { raise Error, 'Missing required field: x_axis' }, %w[kind domain], 'x_axis')
        kind = string(axis, 'kind', required: true)
        raw_domain = array(axis, 'domain', required: true)
        axis_domain = raw_domain.map.with_index do |value, index|
          raise Error, "x_axis domain[#{index}] must be a nonblank string" unless value.is_a?(String) && !value.strip.empty?
          Text.clean(value)
        end
        series = quantitative_records('series', %w[id label focal points], required: true)
        series.each do |item|
          %w[id label].each { |key| string(item, key, required: true) }
          boolean(item, 'focal')
          raw_points = array(item, 'points', required: true)
          item['points'] = raw_points.map do |raw|
            point = object(raw, %w[value gap reason], 'line point')
            if point.keys == ['value']
              { value: quantitative_number(point, 'value') }
            elsif point.keys.sort == %w[gap reason]
              boolean(point, 'gap')
              raise Error, 'Line gap must be true' unless point['gap'] == true
              { gap: true, reason: string(point, 'reason', required: true) }
            else
              raise Error, 'Line point must contain exactly value, or exactly gap and reason'
            end
          end
        end
        SlimGraphR.diagram(:line, **options) do
          x_axis(kind.to_sym, domain: axis_domain)
          scale(**scale) if scale
          series.each do |item|
            series(item.fetch('id'), item.fetch('label'), focal: item.fetch('focal', false)) do
              item.fetch('points').each { |point_item| point_item[:gap] ? gap(reason: point_item[:reason]) : point(point_item[:value]) }
            end
          end
        end
      when :scatter
        options[:x_unit] = string(@data, 'x_unit', required: true)
        options[:y_unit] = string(@data, 'y_unit', required: true)
        x_scale = quantitative_scale('x_scale', required: true)
        y_scale = quantitative_scale('y_scale', required: true)
        points = quantitative_records('points', %w[id label x y focal annotate anonymous], required: true)
        points.each do |item|
          item['x'] = quantitative_number(item, 'x')
          item['y'] = quantitative_number(item, 'y')
          boolean(item, 'anonymous')
          if item['anonymous'] == true
            raise Error, 'Anonymous scatter points contain exactly anonymous, x, and y' unless item.keys.sort == %w[anonymous x y]
          else
            %w[id label].each { |key| string(item, key, required: true) }
            %w[focal annotate].each { |key| boolean(item, key) }
          end
        end
        SlimGraphR.diagram(:scatter, **options) do
          x_scale(**x_scale)
          y_scale(**y_scale)
          points.each do |item|
            if item['anonymous'] == true
              anonymous_point x: item.fetch('x'), y: item.fetch('y')
            else
              point item.fetch('id'), item.fetch('label'), x: item.fetch('x'), y: item.fetch('y'),
                    focal: item.fetch('focal', false), annotate: item.fetch('annotate', false)
            end
          end
        end
      when :treemap
        options[:unit] = string(@data, 'unit', required: true)
        items = quantitative_records('items', %w[id label value focal], required: true)
        items.each do |item|
          %w[id label].each { |key| string(item, key, required: true) }
          item['value'] = quantitative_number(item, 'value')
          boolean(item, 'focal')
        end
        SlimGraphR.diagram(:treemap, **options) do
          items.each { |item| item(item.fetch('id'), item.fetch('label'), item.fetch('value'), focal: item.fetch('focal', false)) }
        end
      when :sankey
        options[:unit] = string(@data, 'unit', required: true)
        options[:balance] = string(@data, 'balance', required: true).to_sym if @data.key?('balance')
        stages = quantitative_records('stages', %w[id label], required: true)
        stages.each { |item| %w[id label].each { |key| string(item, key, required: true) } }
        nodes = quantitative_records('nodes', %w[id stage label value], required: true)
        nodes.each do |item|
          %w[id stage label].each { |key| string(item, key, required: true) }
          item['value'] = quantitative_number(item, 'value')
        end
        flows = quantitative_records('flows', %w[from to value focal], required: true)
        flows.each do |item|
          %w[from to].each { |key| string(item, key, required: true) }
          item['value'] = quantitative_number(item, 'value')
          boolean(item, 'focal')
        end
        SlimGraphR.diagram(:sankey, **options) do
          stages.each { |item| stage(item.fetch('id'), item.fetch('label')) }
          nodes.each { |item| node(item.fetch('id'), stage: item.fetch('stage'), label: item.fetch('label'), value: item.fetch('value')) }
          flows.each { |item| flow(item.fetch('from'), item.fetch('to'), item.fetch('value'), focal: item.fetch('focal', false)) }
        end
      end
    end

    def quantitative_scale(key, required:)
      unless @data.key?(key)
        raise Error, "Missing required field: #{key}" if required
        return nil
      end
      value = object(@data[key], %w[min max], key)
      raise Error, "#{key} must contain exactly min and max" unless value.keys.sort == %w[max min]
      { min: quantitative_number(value, 'min'), max: quantitative_number(value, 'max') }
    end

    def quantitative_records(key, keys, required:)
      raise Error, "Missing required field: #{key}" if required && !@data.key?(key)
      raw = array(@data, key, required: required)
      raw.map { |item| object(item, keys, key) }
    end

    def quantitative_number(record, key)
      raise Error, "Missing required field: #{key}" unless record.key?(key)
      Quantitative::Value.json_number(record[key], key)
    end

    def fishbone_diagram(options)
      allowed = %w[type title description style theme effect categories]
      reject_dedicated_cross_type!('fishbone', allowed)
      raise Error, 'Missing required field: effect' unless @data.key?('effect')
      effect_record = object(@data['effect'], %w[label], 'effect')
      string(effect_record, 'label', required: true)
      categories = records('categories', %w[id label side factors confirmed], 5)
      categories.each do |item|
        %w[id label side].each { |key| string(item, key, required: true) }
        boolean(item, 'confirmed')
        raw_factors = array(item, 'factors', required: true)
        item['factors'] = raw_factors.map.with_index do |value, index|
          unless value.is_a?(String) && !value.strip.empty?
            raise Error, "Fishbone factor[#{index}] must be a nonblank string"
          end
          Text.clean(value)
        end
      end
      SlimGraphR.diagram(:fishbone, **options) do
        effect effect_record.fetch('label')
        categories.each do |item|
          category item.fetch('id'), item.fetch('label'), side: item.fetch('side').to_sym, confirmed: item.fetch('confirmed', false) do
            item.fetch('factors').each { |value| factor value }
          end
        end
      end
    end

    def loop_diagram(options)
      allowed = %w[type title description direction style theme hub stations cycle write_backs]
      reject_dedicated_cross_type!('loop', allowed)
      raise Error, 'Missing required field: direction' unless @data.key?('direction')
      raise Error, 'Missing required field: hub' unless @data.key?('hub')
      hub_record = object(@data['hub'], %w[id label sublabel], 'hub')
      %w[id label].each { |key| string(hub_record, key, required: true) }
      string(hub_record, 'sublabel')
      stations = records('stations', %w[id label sublabel focal], 8)
      stations.each do |item|
        %w[id label].each { |key| string(item, key, required: true) }
        string(item, 'sublabel')
        boolean(item, 'focal')
      end
      raw_cycle = array(@data, 'cycle', required: true)
      cycle_ids = raw_cycle.map.with_index do |value, index|
        unless value.is_a?(String) && !value.strip.empty?
          raise Error, "Loop cycle[#{index}] must be a nonblank string"
        end
        Text.clean(value)
      end
      write_backs = records('write_backs', %w[from to label], 8)
      write_backs.each do |item|
        %w[from to].each { |key| string(item, key, required: true) }
        string(item, 'label')
      end
      SlimGraphR.diagram(:loop, **options) do
        hub hub_record.fetch('id'), hub_record.fetch('label'), sublabel: hub_record['sublabel']
        stations.each do |item|
          station item.fetch('id'), item.fetch('label'), sublabel: item['sublabel'], focal: item.fetch('focal', false)
        end
        cycle(*cycle_ids)
        write_backs.each { |item| write_back item.fetch('from'), to: item.fetch('to'), label: item['label'] }
      end
    end

    def venn_diagram(options)
      allowed = %w[type title description style theme sets intersections]
      reject_dedicated_cross_type!('Venn', allowed)
      sets = records('sets', %w[id label subtitle], 3)
      sets.each do |item|
        %w[id label].each { |key| string(item, key, required: true) }
        string(item, 'subtitle', required: true) if item.key?('subtitle')
      end
      intersections = records('intersections', %w[sets label focal], 4)
      intersections.each do |item|
        string(item, 'label', required: true)
        boolean(item, 'focal')
        raw_members = array(item, 'sets', required: true)
        raise Error, 'Venn intersection sets must contain two or three set IDs' unless raw_members.size.between?(2, 3)
        item['sets'] = raw_members.map.with_index do |value, index|
          unless value.is_a?(String) && !value.strip.empty?
            raise Error, "Venn intersection sets[#{index}] must be a nonblank string"
          end
          Text.clean(value)
        end
      end
      SlimGraphR.diagram(:venn, **options) do
        sets.each { |item| set item.fetch('id'), item.fetch('label'), subtitle: item['subtitle'] }
        intersections.each do |item|
          intersection item.fetch('sets'), item.fetch('label'), focal: item.fetch('focal', false)
        end
      end
    end

    def quadrant_diagram(options)
      allowed = %w[type title description style theme horizontal_axis vertical_axis items regions]
      reject_dedicated_cross_type!('quadrant', allowed)
      axes = %w[horizontal_axis vertical_axis].to_h do |key|
        raise Error, "Missing required field: #{key}" unless @data.key?(key)
        value = object(@data[key], %w[low high], key)
        string(value, 'low', required: true)
        string(value, 'high', required: true)
        [key, value]
      end
      items = records('items', %w[id label x y focal], 12)
      items.each do |item|
        %w[id label].each { |key| string(item, key, required: true) }
        %w[x y].each { |key| number(item, key, required: true) }
        boolean(item, 'focal')
      end
      regions = @data.key?('regions') ? records('regions', %w[position label], 4) : []
      regions.each { |region| %w[position label].each { |key| string(region, key, required: true) } }
      SlimGraphR.diagram(:quadrant, **options) do
        horizontal_axis low: axes.fetch('horizontal_axis').fetch('low'), high: axes.fetch('horizontal_axis').fetch('high')
        vertical_axis low: axes.fetch('vertical_axis').fetch('low'), high: axes.fetch('vertical_axis').fetch('high')
        items.each do |item|
          item item.fetch('id'), item.fetch('label'), x: item.fetch('x'), y: item.fetch('y'), focal: item.fetch('focal', false)
        end
        regions.each { |region| region region.fetch('position').to_sym, region.fetch('label') }
      end
    end

    def wardley_diagram(options)
      allowed = %w[type title description style theme components dependencies]
      reject_dedicated_cross_type!('Wardley', allowed)
      components = records('components', %w[id label evolution visibility evolving_to], 9)
      components.each do |item|
        %w[id label evolution].each { |key| string(item, key, required: true) }
        number(item, 'visibility', required: true)
        string(item, 'evolving_to', required: true) if item.key?('evolving_to')
      end
      dependencies = records('dependencies', %w[from to], 12)
      dependencies.each { |item| %w[from to].each { |key| string(item, key, required: true) } }
      SlimGraphR.diagram(:wardley, **options) do
        components.each do |item|
          component_options = { evolution: item.fetch('evolution'), visibility: item.fetch('visibility') }
          component_options[:evolving_to] = item.fetch('evolving_to') if item.key?('evolving_to')
          component item.fetch('id'), item.fetch('label'), **component_options
        end
        dependencies.each { |item| depends_on item.fetch('from'), item.fetch('to') }
      end
    end

    def uml_class_diagram(options)
      allowed = %w[type title description style theme classes relations]
      reject_dedicated_cross_type!('UML class', allowed)
      classes = records('classes', %w[id label kind focal attributes operations], 7)
      classes.each do |item|
        %w[id label kind].each { |key| string(item, key, required: true) }
        boolean(item, 'focal')
        %w[attributes operations].each do |key|
          next unless item.key?(key)
          values = array(item, key, required: true)
          raise Error, "UML class #{key} exceeds its limit of 5" if values.size > 5
          item[key] = values.map.with_index do |value, index|
            unless value.is_a?(String) && !value.strip.empty?
              raise Error, "UML class #{key}[#{index}] must be a nonblank string"
            end
            value
          end
        end
      end
      relations = records('relations', %w[from to kind label owner from_multiplicity to_multiplicity], 8)
      relations.each do |item|
        %w[from to kind].each { |key| string(item, key, required: true) }
        %w[label owner from_multiplicity to_multiplicity].each { |key| string(item, key, required: true) if item.key?(key) }
      end
      SlimGraphR.diagram(:uml_class, **options) do
        classes.each do |item|
          constructor = { 'class' => :class_type, 'abstract_class' => :abstract_class, 'interface' => :interface }[item.fetch('kind')]
          raise Error, 'UML class kind must be class, abstract_class, or interface' unless constructor
          public_send(constructor, item.fetch('id'), item.fetch('label'), focal: item.fetch('focal', false)) do
            item.fetch('attributes', []).each { |value| attribute value }
            item.fetch('operations', []).each { |value| operation value }
          end
        end
        relations.each do |item|
          relation_options = { kind: item.fetch('kind').to_sym }
          relation_options[:label] = item.fetch('label') if item.key?('label')
          relation_options[:owner] = item.fetch('owner') if item.key?('owner')
          relation_options[:from_multiplicity] = item.fetch('from_multiplicity') if item.key?('from_multiplicity')
          relation_options[:to_multiplicity] = item.fetch('to_multiplicity') if item.key?('to_multiplicity')
          relation item.fetch('from'), item.fetch('to'), **relation_options
        end
      end
    end

    def db_schema_diagram(options)
      allowed = %w[type title description style theme tables foreign_keys]
      reject_dedicated_cross_type!('database schema', allowed)
      tables = records('tables', %w[id label schema columns indexes overflow_columns], 5)
      tables.each do |table|
        %w[id label].each { |key| string(table, key, required: true) }
        string(table, 'schema', required: true) if table.key?('schema')
        raw_columns = array(table, 'columns', required: true)
        raise Error, 'Database table columns exceeds its limit of 8' if raw_columns.size > 8
        table['columns'] = raw_columns.map do |raw_column|
          column = object(raw_column, %w[id label sql_type constraints], 'database column')
          %w[id label sql_type].each { |key| string(column, key, required: true) }
          raw_constraints = array(column, 'constraints', required: true)
          column['constraints'] = raw_constraints.map.with_index do |value, index|
            unless value.is_a?(String) && !value.strip.empty?
              raise Error, "database column constraints[#{index}] must be a nonblank string"
            end
            value
          end
          column
        end
        if table.key?('indexes')
          raw_indexes = array(table, 'indexes', required: true)
          raise Error, 'Database table indexes exceeds its limit of 3' if raw_indexes.size > 3
          table['indexes'] = raw_indexes.map.with_index do |value, index|
            unless value.is_a?(String) && !value.strip.empty?
              raise Error, "database table indexes[#{index}] must be a nonblank string"
            end
            value
          end
        end
        integer(table, 'overflow_columns', minimum: 1, maximum: 99) if table.key?('overflow_columns')
      end
      foreign_keys = records('foreign_keys', %w[from_table from_column to_table to_column on_delete], 6)
      foreign_keys.each do |item|
        %w[from_table from_column to_table to_column on_delete].each { |key| string(item, key, required: true) }
      end
      SlimGraphR.diagram(:db_schema, **options) do
        tables.each do |table_record|
          table_options = {}
          table_options[:schema] = table_record.fetch('schema') if table_record.key?('schema')
          table table_record.fetch('id'), table_record.fetch('label'), **table_options do
            table_record.fetch('columns').each do |column_record|
              column column_record.fetch('id'), column_record.fetch('label'),
                     sql_type: column_record.fetch('sql_type'),
                     constraints: column_record.fetch('constraints').map(&:to_sym)
            end
            table_record.fetch('indexes', []).each { |name| index name }
            overflow_columns table_record.fetch('overflow_columns') if table_record.key?('overflow_columns')
          end
        end
        foreign_keys.each do |item|
          foreign_key item.fetch('from_table'), item.fetch('from_column'),
                      references: [item.fetch('to_table'), item.fetch('to_column')],
                      on_delete: item.fetch('on_delete').to_sym
        end
      end
    end

    def er_diagram(options)
      allowed = %w[type title description style theme entities relationships]
      reject_dedicated_cross_type!('ER', allowed)
      entities = records('entities', %w[id label kind focal fields], 6)
      entities.each do |entity|
        %w[id label].each { |key| string(entity, key, required: true) }
        string(entity, 'kind', required: true) if entity.key?('kind')
        boolean(entity, 'focal')
        raw_fields = array(entity, 'fields', required: true)
        raise Error, 'ER entity fields exceeds its limit of 8' if raw_fields.size > 8
        entity['fields'] = raw_fields.map do |raw_field|
          field = object(raw_field, %w[id label key type qualifier], 'ER field')
          %w[id label].each { |key| string(field, key, required: true) }
          string(field, 'key', required: true) if field.key?('key')
          string(field, 'type', required: true) if field.key?('type')
          string(field, 'qualifier', required: true) if field.key?('qualifier')
          field
        end
      end
      relationships = records('relationships', %w[from to from_cardinality to_cardinality label], 8)
      relationships.each do |item|
        %w[from to from_cardinality to_cardinality].each { |key| string(item, key, required: true) }
        string(item, 'label', required: true) if item.key?('label')
      end
      SlimGraphR.diagram(:er, **options) do
        entities.each do |entity_record|
          entity_options = { focal: entity_record.fetch('focal', false) }
          entity_options[:kind] = entity_record.fetch('kind').to_sym if entity_record.key?('kind')
          entity entity_record.fetch('id'), entity_record.fetch('label'), **entity_options do
            entity_record.fetch('fields').each do |field_record|
              field_options = {}
              field_options[:key] = field_record.fetch('key').to_sym if field_record.key?('key')
              field_options[:type] = field_record.fetch('type') if field_record.key?('type')
              field_options[:qualifier] = field_record.fetch('qualifier') if field_record.key?('qualifier')
              field field_record.fetch('id'), field_record.fetch('label'), **field_options
            end
          end
        end
        relationships.each do |item|
          relationship_options = {
            from: item.fetch('from_cardinality'), to: item.fetch('to_cardinality')
          }
          relationship_options[:label] = item.fetch('label') if item.key?('label')
          relationship item.fetch('from'), item.fetch('to'), **relationship_options
        end
      end
    end

    def dp_security_matrix_diagram(options)
      allowed = %w[type title description style theme roles components permissions]
      reject_dedicated_cross_type!('DP security matrix', allowed)
      roles = records('roles', %w[id label code], 5)
      components = records('components', %w[id label hint], 10)
      permissions = records('permissions', %w[component role label level note focal], 36)
      roles.each do |item|
        %w[id label].each { |key| string(item, key, required: true) }
        string(item, 'code') if item.key?('code')
      end
      components.each do |item|
        %w[id label].each { |key| string(item, key, required: true) }
        string(item, 'hint') if item.key?('hint')
      end
      permissions.each do |item|
        %w[component role level].each { |key| string(item, key, required: true) }
        %w[label note].each { |key| string(item, key, required: true) if item.key?(key) }
        boolean(item, 'focal')
      end
      SlimGraphR.diagram(:dp_security_matrix, **options) do
        roles.each do |item|
          role_options = {}
          role_options[:code] = item.fetch('code') if item.key?('code')
          role item.fetch('id'), item.fetch('label'), **role_options
        end
        components.each do |item|
          component_options = {}
          component_options[:hint] = item.fetch('hint') if item.key?('hint')
          component item.fetch('id'), item.fetch('label'), **component_options
        end
        permissions.each do |item|
          permission_options = { level: item.fetch('level').to_sym, focal: item.fetch('focal', false) }
          permission_options[:note] = item.fetch('note') if item.key?('note')
          if item.key?('label')
            permission item.fetch('component'), item.fetch('role'), item.fetch('label'), **permission_options
          else
            permission item.fetch('component'), item.fetch('role'), **permission_options
          end
        end
      end
    end

    def dp_integration_diagram(options)
      allowed = %w[type title description style theme sources platform consumers layer_services wires]
      reject_dedicated_cross_type!('DP integration', allowed)
      sources = integration_records('sources', %w[id label kind detail], 6) do |item|
        %w[id kind].each { |key| string(item, key, required: true) }
        %w[label detail].each { |key| string(item, key) if item.key?(key) }
      end
      consumers = integration_records('consumers', %w[id label kind detail], 6) do |item|
        %w[id kind].each { |key| string(item, key, required: true) }
        %w[label detail].each { |key| string(item, key) if item.key?(key) }
      end
      layer_services = integration_records('layer_services', %w[id label kind detail protocol], 3) do |item|
        %w[id kind protocol].each { |key| string(item, key, required: true) }
        %w[label detail].each { |key| string(item, key) if item.key?(key) }
      end
      wires = integration_records('wires', %w[from to kind protocol], 20) do |item|
        %w[from to kind].each { |key| string(item, key, required: true) }
        string(item, 'protocol') if item.key?('protocol')
      end

      raise Error, 'Missing required field: platform' unless @data.key?('platform')
      platform = object(@data['platform'], %w[label rows], 'integration platform')
      string(platform, 'label', required: true)
      raw_bands = array(platform, 'rows', required: true)
      raise Error, 'integration platform rows exceeds its limit of 3' if raw_bands.size > 3
      bands = raw_bands.map do |raw_band|
        band = object(raw_band, %w[kind items], 'integration platform row')
        kind = string(band, 'kind', required: true)
        raise Error, 'Integration platform row kind must be row or bar' unless %w[row bar].include?(kind)
        raw_items = array(band, 'items', required: true)
        raise Error, 'An integration bar contains exactly one item' if kind == 'bar' && raw_items.size != 1
        raise Error, 'An integration row contains at most four items' if kind == 'row' && raw_items.size > 4
        band['items'] = raw_items.map do |raw_item|
          item = object(raw_item, %w[id label role detail focal serves], 'integration platform item')
          string(item, 'id', required: true)
          %w[label role detail].each { |key| string(item, key) if item.key?(key) }
          boolean(item, 'focal')
          boolean(item, 'serves')
          item
        end
        band
      end

      SlimGraphR.diagram(:dp_integration, **options) do
        sources.each do |item|
          args = [item.fetch('id')]
          args << item.fetch('label') if item.key?('label')
          source(*args, kind: item.fetch('kind').to_sym, detail: item['detail'])
        end
        platform platform.fetch('label') do
          bands.each do |band|
            if band.fetch('kind') == 'bar'
              item = band.fetch('items').first
              args = [item.fetch('id')]
              args << item.fetch('label') if item.key?('label')
              bar(*args, role: item['role'], detail: item['detail'], focal: item.fetch('focal', false),
                  serves: item.fetch('serves', false))
            else
              row do
                band.fetch('items').each do |item|
                  args = [item.fetch('id')]
                  args << item.fetch('label') if item.key?('label')
                  service(*args, role: item['role'], detail: item['detail'], focal: item.fetch('focal', false),
                          serves: item.fetch('serves', false))
                end
              end
            end
          end
        end
        consumers.each do |item|
          args = [item.fetch('id')]
          args << item.fetch('label') if item.key?('label')
          consumer(*args, kind: item.fetch('kind').to_sym, detail: item['detail'])
        end
        layer_services.each do |item|
          args = [item.fetch('id')]
          args << item.fetch('label') if item.key?('label')
          layer_service(*args, kind: item.fetch('kind').to_sym, detail: item['detail'], protocol: item.fetch('protocol'))
        end
        wires.each do |item|
          options = { kind: item.fetch('kind').to_sym }
          options[:protocol] = item.fetch('protocol') if item.key?('protocol')
          wire item.fetch('from'), item.fetch('to'), **options
        end
      end
    end

    def integration_records(key, keys, limit)
      records(key, keys, limit).each do |item|
        yield item
      end
    end

    def data_flow_diagram(options)
      allowed = %w[type title description style theme roles steps transfers handoffs]
      reject_dedicated_cross_type!('data-flow', allowed)
      roles = data_flow_records('roles', %w[id label key], 4) do |item|
        string(item, 'id', required: true)
        string(item, 'label')
        string(item, 'key', required: true)
      end
      steps = data_flow_records('steps', %w[id label focal], 6) do |item|
        string(item, 'id', required: true)
        string(item, 'label')
        boolean(item, 'focal')
      end
      transfers = data_flow_records('transfers', %w[id label detail role step tool input output focal], 16) do |item|
        %w[id role step tool].each { |key| string(item, key, required: true) }
        string(item, 'label')
        string(item, 'detail', required: true) if item.key?('detail')
        %w[input output].each { |key| string(item, key) if item.key?(key) }
        boolean(item, 'focal')
      end
      handoffs = data_flow_records('handoffs', %w[from to kind label], 20) do |item|
        %w[from to kind].each { |key| string(item, key, required: true) }
        string(item, 'label') if item.key?('label')
      end
      SlimGraphR.diagram(:data_flow, **options) do
        roles.each { |item| role item.fetch('id'), item['label'], key: item.fetch('key') }
        steps.each { |item| step item.fetch('id'), item['label'], focal: item.fetch('focal', false) }
        transfers.each do |item|
          transfer_options = {
            role: item.fetch('role'), step: item.fetch('step'), tool: item.fetch('tool'), focal: item.fetch('focal', false)
          }
          transfer_options[:detail] = item.fetch('detail') if item.key?('detail')
          transfer_options[:input] = item.fetch('input').to_sym if item.key?('input')
          transfer_options[:output] = item.fetch('output').to_sym if item.key?('output')
          transfer item.fetch('id'), item['label'], **transfer_options
        end
        handoffs.each do |item|
          handoff_options = { kind: item.fetch('kind').to_sym }
          handoff_options[:label] = item.fetch('label') if item.key?('label')
          handoff item.fetch('from'), item.fetch('to'), **handoff_options
        end
      end
    end

    def data_flow_records(key, keys, limit)
      list = array(@data, key, required: true)
      raise Error, "#{key} exceeds its limit of #{limit}" if list.size > limit
      list.map do |value|
        item = object(value, keys, "data-flow #{key}")
        yield item
        item
      end
    end

    def journey_diagram(options)
      allowed = %w[type title description style theme persona stages]
      reject_dedicated_cross_type!('journey', allowed)
      raw_stages = array(@data, 'stages', required: true)
      raise Error, 'stages exceeds its limit of 6' if raw_stages.size > 6
      stages = raw_stages.map do |value|
        item = object(value, %w[id label action touchpoint sentiment pains], 'journey stage')
        string(item, 'id', required: true)
        string(item, 'label')
        string(item, 'action', required: true)
        string(item, 'touchpoint', required: true) if item.key?('touchpoint')
        sentiment = string(item, 'sentiment', required: true)
        unless Diagram::JOURNEY_SENTIMENTS.map(&:to_s).include?(sentiment)
          raise Error, "sentiment must be one of #{Diagram::JOURNEY_SENTIMENTS.join(', ')}"
        end
        pains = item.key?('pains') ? array(item, 'pains', required: true) : []
        raise Error, 'pains exceeds its limit of 2' if pains.size > 2
        item['pains'] = pains.each_with_index.map do |pain, index|
          raise Error, "pains[#{index}] must be a nonblank string" unless pain.is_a?(String) && !pain.strip.empty?
          Text.clean(pain)
        end
        item
      end
      SlimGraphR.diagram(:journey, **options) do
        stages.each do |item|
          stage item.fetch('id'), item['label'], sentiment: item.fetch('sentiment').to_sym do
            action item.fetch('action')
            touchpoint item.fetch('touchpoint') if item.key?('touchpoint')
            item.fetch('pains').each { |value| pain value }
          end
        end
      end
    end

    def story_map_diagram(options)
      allowed = %w[type title description style theme persona activities releases]
      reject_dedicated_cross_type!('story-map', allowed)
      raw_activities = array(@data, 'activities', required: true)
      raise Error, 'activities exceeds its limit of 5' if raw_activities.size > 5
      activities = raw_activities.map do |value|
        item = object(value, %w[id label steps], 'story-map activity')
        string(item, 'id', required: true)
        string(item, 'label')
        steps = array(item, 'steps', required: true)
        raise Error, 'steps exceeds its per-activity limit of 2' if steps.size > 2
        item['steps'] = steps.map do |raw_step|
          step = object(raw_step, %w[id label], 'story-map step')
          string(step, 'id', required: true)
          string(step, 'label')
          step
        end
        item
      end
      raw_releases = array(@data, 'releases', required: true)
      raise Error, 'releases exceeds its limit of 3' if raw_releases.size > 3
      releases = raw_releases.map do |value|
        item = object(value, %w[id label cut stories], 'story-map release')
        string(item, 'id', required: true)
        string(item, 'label')
        boolean(item, 'cut')
        stories = array(item, 'stories', required: true)
        item['stories'] = stories.map do |raw_story|
          story = object(raw_story, %w[id label activity estimate ticket risk], 'story-map story')
          string(story, 'id', required: true)
          string(story, 'label')
          string(story, 'activity', required: true)
          %w[estimate ticket].each { |key| string(story, key, required: true) if story.key?(key) }
          boolean(story, 'risk')
          story
        end
        item
      end
      SlimGraphR.diagram(:story_map, **options) do
        activities.each do |item|
          activity item.fetch('id'), item['label'] do
            item.fetch('steps').each { |step_item| step step_item.fetch('id'), step_item['label'] }
          end
        end
        releases.each do |item|
          release item.fetch('id'), item['label'], cut: item.fetch('cut', false) do
            item.fetch('stories').each do |story_item|
              story story_item.fetch('id'), story_item['label'], activity: story_item.fetch('activity'),
                    estimate: story_item['estimate'], ticket: story_item['ticket'], risk: story_item.fetch('risk', false)
            end
          end
        end
      end
    end

    def gantt_diagram(options)
      allowed = %w[type title description style theme phases milestones markers]
      reject_dedicated_cross_type!('Gantt', allowed)
      raw_phases = array(@data, 'phases', required: true)
      raise Error, 'phases exceeds its limit of 4' if raw_phases.size > 4
      task_count = 0
      phases = raw_phases.map do |value|
        phase = object(value, %w[id label tasks], 'phases')
        string(phase, 'id', required: true)
        string(phase, 'label', required: true)
        tasks = array(phase, 'tasks', required: true).map do |raw_task|
          task = object(raw_task, %w[id label start finish focal], 'tasks')
          %w[id label start finish].each { |key| string(task, key, required: true) }
          boolean(task, 'focal')
          task_count += 1
          task
        end
        phase['tasks'] = tasks
        phase
      end
      raise Error, 'tasks exceeds its limit of 12' if task_count > 12
      raw_milestones = array(@data, 'milestones', required: true)
      raise Error, 'milestones exceeds its limit of 8' if raw_milestones.size > 8
      milestones = raw_milestones.map do |value|
        item = object(value, %w[id label on phase], 'milestones')
        %w[id label on].each { |key| string(item, key, required: true) }
        string(item, 'phase', required: true) if item.key?('phase')
        item
      end
      raw_markers = array(@data, 'markers', required: true)
      raise Error, 'markers exceeds its limit of 2' if raw_markers.size > 2
      markers = raw_markers.map do |value|
        item = object(value, %w[id label on], 'markers')
        %w[id label on].each { |key| string(item, key, required: true) }
        item
      end
      SlimGraphR.diagram(:gantt, **options) do
        phases.each do |phase_item|
          phase phase_item.fetch('id'), phase_item.fetch('label') do
            phase_item.fetch('tasks').each do |item|
              task item.fetch('id'), item.fetch('label'), start: item.fetch('start'), finish: item.fetch('finish'),
                   focal: item.fetch('focal', false)
            end
          end
        end
        milestones.each do |item|
          milestone_options = {}
          milestone_options[:phase] = item.fetch('phase') if item.key?('phase')
          milestone item.fetch('id'), item.fetch('label'), on: item.fetch('on'), **milestone_options
        end
        markers.each { |item| marker item.fetch('id'), item.fetch('label'), on: item.fetch('on') }
      end
    end

    def kanban_diagram(options)
      allowed = %w[type title description style theme columns]
      reject_dedicated_cross_type!('Kanban', allowed)
      raw_columns = array(@data, 'columns', required: true)
      raise Error, 'columns must contain two to five entries' unless raw_columns.size.between?(2, 5)
      total = 0
      columns = raw_columns.map do |value|
        column = object(value, %w[id label wip_limit cards], 'columns')
        string(column, 'id', required: true)
        string(column, 'label', required: true)
        integer(column, 'wip_limit', required: true, minimum: 1) if column.key?('wip_limit')
        cards = array(column, 'cards', required: true).map do |raw_card|
          card = object(raw_card, %w[id label ticket owner state focal], 'cards')
          %w[id label].each { |key| string(card, key, required: true) }
          %w[ticket owner state].each { |key| string(card, key, required: true) if card.key?(key) }
          boolean(card, 'focal')
          total += 1
          card
        end
        column['cards'] = cards
        column
      end
      raise Error, 'cards exceeds its input limit of 20' if total > 20
      SlimGraphR.diagram(:kanban, **options) do
        columns.each do |column_item|
          column_options = {}
          column_options[:wip_limit] = column_item.fetch('wip_limit') if column_item.key?('wip_limit')
          column column_item.fetch('id'), column_item.fetch('label'), **column_options do
            column_item.fetch('cards').each do |item|
              card item.fetch('id'), item.fetch('label'), ticket: item['ticket'], owner: item['owner'],
                   state: item.fetch('state', 'default').to_sym, focal: item.fetch('focal', false)
            end
          end
        end
      end
    end

    def workflow_diagram(type, options)
      cards_key = type == :process ? 'operations' : 'activities'
      allowed = COMMON_KEYS + %w[lanes stages handoffs] + [cards_key]
      allowed << 'trigger' if type == :process
      reject_dedicated_cross_type!(type.to_s, allowed)

      lane_keys = type == :process ? %w[id label key] : %w[id label]
      lanes = records('lanes', lane_keys, 6)
      lanes.each do |item|
        string(item, 'id', required: true)
        string(item, 'label')
        string(item, 'key', required: true) if type == :process
      end

      stage_keys = type == :process ? %w[id label focal] : %w[id label]
      stages = records('stages', stage_keys, 12)
      stages.each do |item|
        string(item, 'id', required: true)
        string(item, 'label')
        boolean(item, 'focal') if type == :process
      end

      card_keys = if type == :process
        %w[id label lane stage tool detail input output focal]
      else
        %w[id label lane stage detail focal]
      end
      cards = records(cards_key, card_keys, 24)
      cards.each do |item|
        %w[id lane stage].each { |key| string(item, key, required: true) }
        string(item, 'label')
        if type == :swimlane
          string(item, 'detail')
          boolean(item, 'focal')
          next
        end
        string(item, 'tool', required: true)
        string(item, 'detail')
        %w[input output].each do |key|
          next unless item.key?(key)
          string(item, key) unless item[key].nil?
        end
        boolean(item, 'focal')
      end

      handoff_keys = type == :swimlane ? %w[from to label focal dashed] : %w[from to]
      handoffs = records('handoffs', handoff_keys, 24)
      handoffs.each do |item|
        %w[from to].each { |key| string(item, key, required: true) }
        if type == :swimlane
          string(item, 'label')
          boolean(item, 'focal')
          boolean(item, 'dashed')
        end
      end

      trigger = nil
      if @data.key?('trigger')
        trigger = object(@data['trigger'], %w[from to label], 'trigger')
        %w[from to label].each { |key| string(trigger, key, required: true) }
      end

      SlimGraphR.diagram(type, **options) do
        lanes.each do |item|
          lane_options = type == :process ? { key: item.fetch('key') } : {}
          lane item.fetch('id'), item['label'], **lane_options
        end
        stages.each do |item|
          stage_options = type == :process ? { focal: item.fetch('focal', false) } : {}
          stage item.fetch('id'), item['label'], **stage_options
        end
        cards.each do |item|
          if type == :process
            payloads = {}
            payloads[:input] = item['input'] if item.key?('input')
            payloads[:output] = item['output'] if item.key?('output')
            operation item.fetch('id'), item['label'], lane: item.fetch('lane'), stage: item.fetch('stage'),
                      tool: item.fetch('tool'), detail: item['detail'], focal: item.fetch('focal', false), **payloads
          else
            activity item.fetch('id'), item['label'], lane: item.fetch('lane'), stage: item.fetch('stage'),
                     detail: item['detail'], focal: item.fetch('focal', false)
          end
        end
        handoffs.each do |item|
          handoff_options = type == :swimlane ? { focal: item.fetch('focal', false), dashed: item.fetch('dashed', false) } : {}
          if type == :swimlane && item.key?('label')
            handoff item.fetch('from'), item.fetch('to'), item.fetch('label'), **handoff_options
          else
            handoff item.fetch('from'), item.fetch('to'), **handoff_options
          end
        end
        trigger(trigger.fetch('from'), trigger.fetch('to'), trigger.fetch('label')) if trigger
      end
    end

    def pyramid_diagram(options)
      reject_dedicated_cross_type!('pyramid', COMMON_KEYS.reject { |key| key == 'direction' } + %w[orientation mode unit levels])
      levels = records('levels', %w[id label detail from to focal], 6)
      levels.each do |item|
        string(item, 'id', required: true)
        %w[label detail].each { |key| string(item, key) }
        number(item, 'from')
        number(item, 'to')
        boolean(item, 'focal')
      end
      SlimGraphR.diagram(:pyramid, **options) do
        levels.each do |item|
          quantities = {}
          quantities[:from] = item['from'] if item.key?('from')
          quantities[:to] = item['to'] if item.key?('to')
          level item.fetch('id'), item['label'], detail: item['detail'], focal: item.fetch('focal', false), **quantities
        end
      end
    end

    def medallion_diagram(options)
      allowed = COMMON_KEYS.reject { |key| key == 'direction' } + %w[tiers promotions write_paths]
      reject_dedicated_cross_type!('medallion', allowed)
      tiers = records('tiers', %w[id label bucket tool format writer examples focal archive concern], 6)
      tiers.each do |item|
        string(item, 'id', required: true)
        string(item, 'label')
        %w[bucket tool format writer].each { |key| string(item, key, required: true) }
        examples = array(item, 'examples', required: true)
        examples.each_with_index do |value, index|
          raise Error, "examples[#{index}] must be a nonblank string" unless value.is_a?(String) && !value.strip.empty?
        end
        boolean(item, 'focal')
        boolean(item, 'archive')
        string(item, 'concern')
      end
      promotions = records('promotions', %w[from to label], 5)
      promotions.each { |item| %w[from to label].each { |key| string(item, key, required: true) } }
      paths = records('write_paths', %w[id tag title detail concern], 2)
      paths.each do |item|
        %w[id tag title detail].each { |key| string(item, key, required: true) }
        string(item, 'concern')
      end
      SlimGraphR.diagram(:medallion, **options) do
        tiers.each do |item|
          tier item.fetch('id'), item['label'], bucket: item.fetch('bucket'), tool: item.fetch('tool'),
               format: item.fetch('format'), writer: item.fetch('writer'), examples: item.fetch('examples'),
               focal: item.fetch('focal', false), archive: item.fetch('archive', false), concern: item['concern']
        end
        promotions.each { |item| promote item.fetch('from'), item.fetch('to'), item.fetch('label') }
        paths.each do |item|
          write_path item.fetch('id'), tag: item.fetch('tag'), title: item.fetch('title'), detail: item.fetch('detail'),
                     concern: item['concern']
        end
      end
    end

    def tree_diagram(options)
      reject_dedicated_cross_type!('tree', COMMON_KEYS + %w[root])
      raise Error, 'Missing required field: root' unless @data.key?('root')
      root = tree_record(@data['root'], 1)
      reader = self
      SlimGraphR.diagram(:tree, **options) { reader.send(:apply_tree, self, root, root: true) }
    end

    def tree_record(value, depth)
      raise Error, 'Tree JSON nesting exceeds four tiers' if depth > 4
      record = object(value, %w[id label detail focal children], 'tree node')
      string(record, 'id', required: true)
      string(record, 'label')
      string(record, 'detail')
      boolean(record, 'focal')
      children = array(record, 'children')
      raise Error, 'A tree parent accepts at most five children' if children.size > 5
      record['children'] = children.map { |child| tree_record(child, depth + 1) }
      record
    end

    def apply_tree(builder, record, root: false)
      method = root ? :root : :child
      reader = self
      builder.public_send(
        method, record.fetch('id'), record['label'], detail: record['detail'], focal: record.fetch('focal', false)
      ) do
        record.fetch('children').each { |child| reader.send(:apply_tree, builder, child) }
      end
    end

    def nested_diagram(options)
      reject_dedicated_cross_type!('nested-containment', COMMON_KEYS + %w[scope])
      raise Error, 'Missing required field: scope' unless @data.key?('scope')
      outer = containment_record(@data['scope'], 1)
      reader = self
      SlimGraphR.diagram(:nested, **options) { reader.send(:apply_containment, self, outer) }
    end

    def containment_record(value, depth)
      raise Error, 'Nested-containment JSON exceeds five levels' if depth > 5
      record = object(value, %w[id label scope], 'containment scope')
      string(record, 'id', required: true)
      string(record, 'label')
      record['scope'] = containment_record(record['scope'], depth + 1) if record.key?('scope')
      record
    end

    def apply_containment(builder, record)
      reader = self
      builder.scope(record.fetch('id'), record['label']) do
        reader.send(:apply_containment, builder, record.fetch('scope')) if record.key?('scope')
      end
    end

    def layers_diagram(options)
      reject_dedicated_cross_type!('layer-stack', COMMON_KEYS + %w[axis indicator layers])
      layers = records('layers', %w[id label index detail focal], 6)
      layers.each do |item|
        string(item, 'id', required: true)
        string(item, 'label')
        string(item, 'index', required: true)
        string(item, 'detail')
        boolean(item, 'focal')
      end
      SlimGraphR.diagram(:layers, **options) do
        layers.each do |item|
          layer item.fetch('id'), item['label'], index: item.fetch('index'), detail: item['detail'],
                focal: item.fetch('focal', false)
        end
      end
    end

    def reject_dedicated_cross_type!(name, allowed)
      forbidden = @data.keys - allowed
      return if forbidden.empty?
      raise Error, "A #{name} diagram does not accept cross-type fields: #{forbidden.join(', ')}"
    end

    def high_level_diagram(options)
      forbidden = @data.keys & %w[axis indicator root scope layers nodes edges groups events steps escalations approvals states initial finals transitions zones paths handoffs]
      unless forbidden.empty?
        raise Error, "A high-level diagram does not accept cross-type fields: #{forbidden.join(', ')}"
      end
      phases = records('phases', %w[id label columns sources components], 5)
      source_count = 0
      component_count = 0
      phases.each do |phase|
        string(phase, 'id', required: true)
        string(phase, 'label')
        integer(phase, 'columns', minimum: 1, maximum: 2)
        raw_sources = array(phase, 'sources')
        raw_components = array(phase, 'components')
        phase['sources'] = raw_sources.map do |value|
          source = object(value, %w[id label type detail], 'high-level source')
          string(source, 'id', required: true)
          %w[label detail].each { |key| string(source, key) }
          source_type = string(source, 'type', required: true)
          unless Diagram::HIGH_LEVEL_SOURCE_TYPES.map(&:to_s).include?(source_type)
            raise Error, "Source type must be one of #{Diagram::HIGH_LEVEL_SOURCE_TYPES.join(', ')}"
          end
          source_count += 1
          source
        end
        phase['components'] = raw_components.map do |value|
          component = object(value, %w[id label role detail focal], 'high-level component')
          string(component, 'id', required: true)
          string(component, 'label')
          string(component, 'role', required: true)
          string(component, 'detail')
          boolean(component, 'focal')
          component_count += 1
          component
        end
      end
      raise Error, 'High-level diagrams need one to four sources' unless source_count.between?(1, 4)
      raise Error, 'High-level diagram limit: eight components' if component_count > 8

      connections = records('connections', %w[from to], 12)
      connections.each do |item|
        string(item, 'from', required: true)
        string(item, 'to', required: true)
      end

      orchestration = nil
      if @data.key?('orchestration')
        orchestration = object(@data['orchestration'], %w[id label detail concern targets], 'orchestration')
        string(orchestration, 'id', required: true)
        %w[label detail concern].each { |key| string(orchestration, key) }
        targets = array(orchestration, 'targets', required: true)
        orchestration['targets'] = targets.each_with_index.map do |target, index|
          raise Error, "orchestration targets[#{index}] must be a string" unless target.is_a?(String)
          raise Error, "orchestration targets[#{index}] must not be empty" if target.strip.empty?
          Text.clean(target)
        end
      end

      crosscuts = records('crosscuts', %w[id label detail concern], 2)
      crosscuts.each do |item|
        string(item, 'id', required: true)
        %w[label detail].each { |key| string(item, key) }
        string(item, 'concern', required: true)
      end

      SlimGraphR.diagram(:high_level, **options) do
        phases.each do |phase_item|
          phase phase_item.fetch('id'), phase_item['label'], columns: phase_item.fetch('columns', 1) do
            phase_item.fetch('sources').each do |item|
              source item.fetch('id'), item['label'], type: item.fetch('type').to_sym, detail: item['detail']
            end
            phase_item.fetch('components').each do |item|
              component item.fetch('id'), item['label'], role: item.fetch('role'), detail: item['detail'],
                        focal: item.fetch('focal', false)
            end
          end
        end
        connections.each { |item| connect item.fetch('from'), item.fetch('to') }
        if orchestration
          orchestrate orchestration.fetch('id'), orchestration['label'], detail: orchestration['detail'],
                      concern: orchestration.fetch('concern', 'Orchestration'), targets: orchestration.fetch('targets')
        end
        crosscuts.each do |item|
          crosscut item.fetch('id'), item['label'], detail: item['detail'], concern: item.fetch('concern')
        end
      end
    end

    def it_state_diagram(options)
      forbidden = @data.keys & %w[cluster axis indicator root scope layers nodes edges groups events steps escalations approvals states initial finals transitions zones paths connections orchestration]
      unless forbidden.empty?
        raise Error, "An IT current-state diagram does not accept cross-type fields: #{forbidden.join(', ')}"
      end
      phases = records('phases', %w[id label systems], 4)
      phases.each do |phase|
        string(phase, 'id', required: true)
        string(phase, 'label')
        systems = array(phase, 'systems', required: true)
        raise Error, 'systems exceeds its per-phase limit of 5' if systems.size > 5
        phase['systems'] = systems.map do |value|
          system = object(value, %w[id label detail state], 'systems')
          string(system, 'id', required: true)
          %w[label detail state].each { |key| string(system, key) }
          system
        end
      end
      handoffs = records('handoffs', %w[from to label style dashed], 24)
      handoffs.each do |item|
        %w[from to label].each { |key| string(item, key, required: true) }
        string(item, 'style')
        boolean(item, 'dashed')
      end
      crosscuts = records('crosscuts', %w[id label detail], 3)
      crosscuts.each do |item|
        string(item, 'id', required: true)
        %w[label detail].each { |key| string(item, key) }
      end
      SlimGraphR.diagram(:it_state, **options) do
        phases.each do |phase_item|
          phase phase_item.fetch('id'), phase_item['label'] do
            phase_item.fetch('systems').each do |item|
              system item.fetch('id'), item['label'], detail: item['detail'], state: item.fetch('state', 'standard').to_sym
            end
          end
        end
        handoffs.each do |item|
          handoff item.fetch('from'), item.fetch('to'), item.fetch('label'),
                  style: item.fetch('style', 'neutral').to_sym, dashed: item.fetch('dashed', false)
        end
        crosscuts.each do |item|
          crosscut item.fetch('id'), item['label'], detail: item['detail']
        end
      end
    end

    def deployment_diagram(options)
      forbidden = @data.keys & %w[cluster axis indicator root scope layers nodes edges groups events steps escalations approvals states initial finals transitions phases handoffs crosscuts connections orchestration]
      unless forbidden.empty?
        raise Error, "A deployment diagram does not accept cross-type fields: #{forbidden.join(', ')}"
      end
      zones = records('zones', %w[id label nodes], 3)
      node_count = 0
      artifact_count = 0
      zones.each do |zone|
        string(zone, 'id', required: true)
        string(zone, 'label')
        raw_nodes = array(zone, 'nodes', required: true)
        zone['nodes'] = raw_nodes.map do |value|
          node = object(value, %w[id label kind replicas emphasis artifacts], 'deployment node')
          string(node, 'id', required: true)
          string(node, 'label')
          kind = string(node, 'kind', required: true)
          unless Diagram::INFRASTRUCTURE_KINDS.map(&:to_s).include?(kind)
            raise Error, "Deployment node kind must be one of #{Diagram::INFRASTRUCTURE_KINDS.join(', ')}"
          end
          integer(node, 'replicas', minimum: 1)
          boolean(node, 'emphasis')
          artifacts = array(node, 'artifacts', required: true).map do |item|
            artifact = object(item, %w[name version], 'artifact')
            string(artifact, 'name', required: true)
            string(artifact, 'version', required: true)
            artifact_count += 1
            artifact
          end
          node['artifacts'] = artifacts
          node_count += 1
          node
        end
      end
      raise Error, 'Deployment diagram limit: six infrastructure nodes. Split the diagram by environment.' if node_count > 6
      raise Error, 'Deployment diagram limit: nine artifact chips. Split the diagram by environment.' if artifact_count > 9
      paths = records('paths', %w[from to protocol port async emphasis], 8)
      paths.each do |item|
        %w[from to protocol].each { |key| string(item, key, required: true) }
        integer(item, 'port', required: true, minimum: 1, maximum: 65_535)
        boolean(item, 'async')
        boolean(item, 'emphasis')
      end
      SlimGraphR.diagram(:deployment, **options) do
        zones.each do |zone_item|
          zone zone_item.fetch('id'), zone_item['label'] do
            zone_item.fetch('nodes').each do |node|
              public_send(node.fetch('kind'), node.fetch('id'), node['label'],
                          replicas: node.fetch('replicas', 1), emphasis: node.fetch('emphasis', false)) do
                node.fetch('artifacts').each { |item| artifact item.fetch('name'), version: item.fetch('version') }
              end
            end
          end
        end
        paths.each do |item|
          network item.fetch('from'), item.fetch('to'), protocol: item.fetch('protocol'), port: item.fetch('port'),
                  async: item.fetch('async', false), emphasis: item.fetch('emphasis', false)
        end
      end
    end

    def dependency_diagram(options)
      forbidden = @data.keys & %w[cluster axis indicator root scope layers groups events steps escalations approvals states initial finals transitions zones paths phases handoffs crosscuts connections orchestration]
      unless forbidden.empty?
        raise Error, "A dependency diagram does not accept cross-type fields: #{forbidden.join(', ')}"
      end
      nodes = records('nodes', %w[id label kind version registry], 9)
      edges = records('edges', %w[from to cycle], 14)
      nodes.each do |item|
        string(item, 'id', required: true)
        string(item, 'label')
        kind = string(item, 'kind')
        raise Error, 'Dependency node kind must be external when supplied' if kind && kind != 'external'
        if kind == 'external'
          string(item, 'version', required: true)
          string(item, 'registry', required: true)
        elsif item.key?('version') || item.key?('registry')
          raise Error, 'version and registry require kind: external'
        end
      end
      edges.each do |item|
        string(item, 'from', required: true)
        string(item, 'to', required: true)
        boolean(item, 'cycle')
      end
      SlimGraphR.diagram(:dependency, **options) do
        nodes.each do |item|
          if item['kind'] == 'external'
            external_dependency item.fetch('id'), item['label'], version: item.fetch('version'), registry: item.fetch('registry')
          else
            dependency item.fetch('id'), item['label']
          end
        end
        edges.each { |item| depends_on item.fetch('from'), item.fetch('to'), cycle: item.fetch('cycle', false) }
      end
    end

    def state_diagram(options)
      forbidden = @data.keys & %w[cluster axis indicator root scope layers nodes edges groups events steps escalations approvals zones paths phases handoffs crosscuts connections orchestration]
      unless forbidden.empty?
        raise Error, "A state machine does not accept cross-type fields: #{forbidden.join(', ')}"
      end
      states = records('states', %w[id label detail emphasis], 12)
      transitions = records('transitions', %w[from to on guard action], 24)
      initial = string(@data, 'initial', required: true)
      finals_value = @data['finals']
      raise Error, 'Missing required field: finals' unless @data.key?('finals')
      raise Error, 'finals must be an array' unless finals_value.is_a?(Array)
      raise Error, 'finals exceeds its limit of 2' if finals_value.size > 2
      finals = finals_value.each_with_index.map do |value, index|
        raise Error, "finals[#{index}] must be a string" unless value.is_a?(String)
        raise Error, "finals[#{index}] must not be empty" if value.strip.empty?
        Text.clean(value)
      end
      states.each do |item|
        string(item, 'id', required: true)
        string(item, 'label')
        string(item, 'detail', required: true) if item.key?('detail')
        boolean(item, 'emphasis')
      end
      transitions.each do |item|
        %w[from to on].each { |key| string(item, key, required: true) }
        %w[guard action].each do |key|
          value = string(item, key)
          raise Error, "#{key} must not be empty" if value && value.strip.empty?
        end
      end
      SlimGraphR.diagram(:state, **options) do
        states.each { |item| state item.fetch('id'), item['label'], detail: item['detail'], emphasis: item.fetch('emphasis', false) }
        initial initial
        finals.each { |id| final id }
        transitions.each do |item|
          transition item.fetch('from'), item.fetch('to'), on: item.fetch('on'), guard: item['guard'], action: item['action']
        end
      end
    end

    def sequence_steps(value, depth = 0)
      raise Error, 'Sequence steps must be an array' unless value.is_a?(Array)
      raise Error, 'Sequence input nesting exceeds eight levels' if depth > 8
      raise Error, 'Sequence steps exceed the 64-action input limit' if value.size > 64
      value.map do |step|
        @action_count += 1
        raise Error, 'Sequence steps exceed the 64-action input limit' if @action_count > 64
        raise Error, 'A sequence step must be an object' unless step.is_a?(Hash)
        kinds = step.keys & %w[message activate alt opt loop]
        raise Error, 'A sequence step needs exactly one of message/activate/alt/opt/loop' unless kinds.size == 1
        kind = kinds.first
        object(step, %w[message alt].include?(kind) ? [kind] : [kind, 'steps'], 'sequence step')
        case kind
        when 'message'
          edge = object(step[kind], %w[from to label kind dashed], 'message')
          %w[from to label kind].each { |key| string(edge, key, required: %w[from to].include?(key)) }
          boolean(edge, 'dashed')
          { type: :message, message: edge }
        when 'alt'
          regions = step[kind]
          raise Error, 'alt needs exactly two regions' unless regions.is_a?(Array) && regions.size == 2
          parsed = regions.map do |region|
            object(region, %w[guard steps], 'region')
            { guard: string(region, 'guard', required: true), steps: sequence_steps(region['steps'], depth + 1) }
          end
          { type: :alt, regions: parsed }
        else
          label = string(step, kind, required: true)
          { type: kind.to_sym, actor: label, guard: label, steps: sequence_steps(step['steps'], depth + 1) }
        end
      end
    end

    def object(value, keys, context)
      raise Error, "#{context} must be a JSON object" unless value.is_a?(Hash)
      unknown = value.keys - keys
      raise Error, "Unknown #{context} fields: #{unknown.join(', ')}" unless unknown.empty?
      value
    end

    def array(record, key, required: false)
      unless record.key?(key)
        raise Error, "Missing required field: #{key}" if required
        return []
      end
      value = record[key]
      raise Error, "#{key} must be an array" unless value.is_a?(Array)
      value
    end

    def integer(record, key, required: false, minimum: nil, maximum: nil)
      unless record.key?(key)
        raise Error, "Missing required field: #{key}" if required
        return nil
      end
      value = record[key]
      range = [minimum, maximum].compact
      invalid = !value.is_a?(Integer) || (minimum && value < minimum) || (maximum && value > maximum)
      if invalid
        bounds = if range.size == 2 then " from #{minimum} to #{maximum}"
                 elsif minimum then " at least #{minimum}"
                 else ''
                 end
        raise Error, "#{key} must be an integer#{bounds}"
      end
      value
    end

    def number(record, key, required: false)
      unless record.key?(key)
        raise Error, "Missing required field: #{key}" if required
        return nil
      end
      value = record[key]
      unless (value.is_a?(Integer) || value.is_a?(Float)) && value.finite?
        raise Error, "#{key} must be a finite number"
      end
      value
    end

    def records(key, keys, limit)
      list = @data.fetch(key, [])
      raise Error, "#{key} must be an array" unless list.is_a?(Array)
      raise Error, "#{key} exceeds its limit of #{limit}" if list.size > limit
      list.map { |v| object(v, keys, key) }
    end

    def string(record, key, required: false)
      if !record.key?(key)
        raise Error, "Missing required field: #{key}" if required
        return nil
      end
      value = record[key]
      raise Error, "#{key} must be a string" unless value.is_a?(String)
      raise Error, "#{key} must not be empty" if required && value.strip.empty?
      Text.clean(value)
    end

    def boolean(record, key)
      return unless record.key?(key)
      raise Error, "#{key} must be true or false" unless [true, false].include?(record[key])
    end
  end
end
