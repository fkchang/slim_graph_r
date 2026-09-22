# frozen_string_literal: true
module SlimGraphR
  class SVG
    BODY_TEXT_SIZE = 14
    READABLE_BODY_SIZE = 14
    READABLE_METADATA_SIZE = 12
    MINIMUM_TEXT_SIZE = {
      architecture: 12, data_flow: 12, db_schema: 9, dependency: 8, deployment: 8,
      dp_integration: 12, dp_security_matrix: 8, er: 8, flowchart: 12, gantt: 8,
      high_level: 12, it_state: 9, journey: 12, kanban: 8, layers: 9,
      medallion: 8, nested: 8, org_chart: 10, process: 12, pyramid: 10,
      sequence: 12, state: 12, story_map: 12, swimlane: 12, timeline: 12, tree: 9,
      uml_class: 8, quadrant: 8, venn: 12, loop: 12, fishbone: 12, wardley: 12,
      bar: 12, line: 12, scatter: 12, treemap: 12, sankey: 12, polar: 12, radar: 12
    }.freeze

    def initialize(diagram, scene, id: nil, motion: nil, motion_static: false)
      @d, @s = diagram, scene
      @motion = motion
      @motion_static = motion_static
      @motion_matches = {}
      @id = id || "sgr-#{SecureRandom.hex(6)}"
      raise Error, 'SVG ID must start with a letter and contain only letters, digits, hyphens, underscores' unless @id.match?(/\A[a-zA-Z][a-zA-Z0-9_-]*\z/)
      @out = []
    end

    def render
      header = header_layout
      header_height = header[:height]
      height = @s.height + header_height
      type_attr = if @d.type == :it_state then ' data-sgr-it-state="true"'
                  elsif @d.type == :data_flow then ' data-sgr-data-flow="true"'
                  elsif @d.type == :dp_integration then ' data-sgr-dp-integration="true"'
                  elsif @d.type == :dp_security_matrix then ' data-sgr-dp-security-matrix="true"'
                  elsif @d.type == :er then ' data-er="true"'
                  elsif @d.type == :db_schema then ' data-sgr-db-schema-diagram="true"'
                  elsif @d.type == :uml_class then ' data-sgr-uml-class="true"'
                  elsif @d.type == :quadrant then ' data-sgr-quadrant="true"'
                  elsif @d.type == :venn then ' data-sgr-venn="true"'
                  elsif @d.type == :loop then ' data-sgr-loop="true" data-sgr-loop-direction="clockwise"'
                  elsif @d.type == :fishbone then ' data-sgr-fishbone="true"'
                  elsif @d.type == :wardley then ' data-sgr-wardley="true"'
                  elsif @d.type == :high_level then ' data-sgr-high-level="true"'
                  elsif @d.type == :tree then %( data-sgr-tree="true" data-sgr-tree-direction="#{@d.direction}")
                  elsif @d.type == :nested then ' data-sgr-nested="true"'
                  elsif @d.type == :layers then ' data-sgr-layers="true"'
                  elsif @d.type == :pyramid then %( data-sgr-pyramid="true" data-sgr-pyramid-orientation="#{@d.orientation}" data-sgr-pyramid-mode="#{@d.mode}")
                  elsif @d.type == :medallion then ' data-sgr-medallion="true"'
                  elsif @d.type == :swimlane then ' data-sgr-swimlane="true"'
                  elsif @d.type == :process then ' data-sgr-process="true"'
                  elsif @d.type == :gantt then ' data-sgr-gantt="true"'
                  elsif @d.type == :kanban then ' data-sgr-kanban="true"'
                  elsif @d.type == :journey then ' data-sgr-journey="true"'
                  elsif @d.type == :story_map then ' data-sgr-story-map="true"'
                  else ''
                  end
      display_scale = readable_display_scale
      display_width = (@s.width * display_scale).ceil
      display_height = (height * display_scale).ceil
      add %(<svg xmlns="http://www.w3.org/2000/svg" id="#{@id}" class="sgr-diagram" data-sgr-theme="#{@d.theme}" data-sgr-style="#{@d.style}"#{type_attr} data-sgr-display-scale="#{format('%.4g', display_scale)}" role="img" aria-labelledby="#{@id}-title #{@id}-desc" viewBox="0 0 #{@s.width} #{height}" width="#{display_width}" height="#{display_height}" style="display:block;margin:0 auto;width:100%;height:auto;min-width:#{display_width}px">)
      description = if @motion_static
        steps = @motion.steps.map { |step| "Step #{step.number}: #{step.label}" }.join('. ')
        "#{@d.title}. Final frame of an ordered reveal. #{steps}."
      else
        accessible_description
      end
      add %(<title id="#{@id}-title">#{esc(@d.title)}</title><desc id="#{@id}-desc">#{esc(description)}</desc>)
      add "<style>#{styles}</style>"
      add '<defs>' unless %i[dp_security_matrix er].include?(@d.type)
      unless %i[dp_security_matrix er].include?(@d.type)
      {
        'arrow' => ['var(--sgr-muted)', false], 'arrow-open' => ['var(--sgr-muted)', true],
        'arrow-link' => ['var(--sgr-link)', false], 'arrow-link-open' => ['var(--sgr-link)', true],
        'arrow-accent' => ['var(--sgr-accent)', false], 'arrow-accent-open' => ['var(--sgr-accent)', true]
      }.each do |name, (color, open)|
        path = open ? 'M 1 1 L 7 4 L 1 7' : 'M 1 1 L 7 4 L 1 7 Z'
        add %(<marker id="#{@id}-#{name}" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="8" markerHeight="8" orient="auto-start-reverse" markerUnits="userSpaceOnUse"><path d="#{path}" fill="#{open ? 'none' : color}" stroke="#{color}" stroke-width="1.2"/></marker>)
      end
      %i[security quality product analysis].each do |concern|
        add %(<marker id="#{@id}-arrow-#{concern}" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="8" markerHeight="8" orient="auto" markerUnits="userSpaceOnUse"><path d="M 1 1 L 7 4 L 1 7 Z" fill="var(--sgr-concern-#{concern})" stroke="var(--sgr-concern-#{concern})" stroke-width="1.2"/></marker>)
      end
      add %(<marker id="#{@id}-arrow-sm" viewBox="0 0 6 5" refX="5" refY="2.5" markerWidth="6" markerHeight="5" orient="auto" markerUnits="userSpaceOnUse"><path d="M 0 0 L 6 2.5 L 0 5 Z" fill="var(--sgr-muted)"/></marker>)
      add uml_marker_definitions if @d.type == :uml_class
      end
      add '</defs>' unless %i[dp_security_matrix er].include?(@d.type)
      rect(0, 0, @s.width, height, fill: 'var(--sgr-paper)')
      if @d.type == :it_state
        header[:eyebrow_lines].each_with_index do |value, index|
          text(value, 40, header[:eyebrow_y] + index * 14, class: 'sgr-it-eyebrow', 'data-sgr-eyebrow': 'true')
        end
        header[:title_lines].each_with_index { |value, index| text(value, 40, header[:title_y] + index * 36, class: 'sgr-title') }
        header[:subtitle_lines].each_with_index do |value, index|
          text(value, 40, header[:subtitle_y] + index * 20, class: 'sgr-it-subtitle', 'data-sgr-subtitle': 'true')
        end
      else
        header[:title_lines].each_with_index { |value, index| text(value, 40, 48 + index * 36, class: 'sgr-title') }
      end
      if @d.type == :dp_security_matrix
        rect(40, header_height - 8, @s.width - 80, 1, fill: 'var(--sgr-rule)')
      else
        line(40, header_height - 8, @s.width - 40, header_height - 8, 'var(--sgr-rule)')
      end
      add %(<g transform="translate(0 #{header_height})">)
      if @d.type == :data_flow
        draw_data_flow
      elsif @d.type == :dp_integration
        draw_dp_integration
      elsif @d.type == :dp_security_matrix
        draw_dp_security_matrix
      elsif @d.type == :er
        draw_er
      elsif @d.type == :db_schema
        draw_db_schema
      elsif @d.type == :uml_class
        draw_uml_class
      elsif @d.type == :quadrant
        draw_quadrant
      elsif @d.type == :venn
        draw_venn
      elsif @d.type == :loop
        draw_loop
      elsif @d.type == :fishbone
        draw_fishbone
      elsif @d.type == :wardley
        draw_wardley
      elsif @d.type == :high_level
        draw_high_level
      elsif @d.type == :tree
        draw_tree
      elsif @d.type == :nested
        draw_nested
      elsif @d.type == :layers
        draw_layers
      elsif @d.type == :pyramid
        draw_pyramid
      elsif @d.type == :medallion
        draw_medallion
      elsif @d.type == :state
        draw_state_machine
      elsif @d.type == :it_state
        draw_it_state
      elsif %i[swimlane process].include?(@d.type)
        draw_workflow
      elsif %i[gantt kanban].include?(@d.type)
        draw_planning_board
      elsif %i[journey story_map].include?(@d.type)
        draw_journey_family
      else
        @s.zones.each { |zone| draw_zone(zone) }
        (@s.fragments || []).each { |frame| draw_frame(frame) }
        @s.lifelines.each { |x, y1, y2| line(x, y1, x, y2, 'var(--sgr-rule)', dashed: true) }
        (@s.activations || []).each { |bar| draw_activation(bar) }
        previous_routes = []
        @s.routes.sort_by { |route| route.edge.dashed ? 1 : 0 }.each do |route|
          draw_route(route, previous_routes)
          previous_routes << route
        end
        if %i[dependency deployment].include?(@d.type)
          @s.routes.each do |route|
            motion_route_item(route.edge.from, route.edge.to) { draw_label(route.label_box) } if route.label_box
          end
          @s.boxes.each { |box| draw_box(box) }
        else
          @s.boxes.each { |box| draw_box(box) }
          @s.routes.each do |route|
            motion_route_item(route.edge.from, route.edge.to) { draw_label(route.label_box) } if route.label_box
          end
        end
        draw_org_callouts unless (@s.callouts || []).empty?
        (@s.fragments || []).each { |frame| draw_frame_captions(frame) }
        draw_timeline unless @s.events.empty?
      end
      add '</g></svg>'
      @motion&.validate_rendered!(@motion_matches.keys)
      @out.join
    end

    private

    def styles
      light_roles = @d.style_profile.light
      dark_roles = @d.style_profile.dark
      concern_light, concern_dark = concern_palettes
      payload_light = { ls: '#7c8f6f', db: '#5e7a9b', tb: '#b8915a', fl: '#9c6b50', wb: '#6e6479',
                        web: '#6e6479', dataset: '#5e7a9b', table: '#b8915a', file: '#9c6b50', stream: '#497d78' }
      payload_dark = { ls: '#9caf8f', db: '#82a0c0', tb: '#d3ad7a', fl: '#b88670', wb: '#8d8298',
                       web: '#8d8298', dataset: '#82a0c0', table: '#d3ad7a', file: '#b88670', stream: '#70aaa4' }
      light = light_roles.map { |k, v| "--sgr-#{k}:#{v}" }.join(';') + concern_light.map { |k, v| ";--sgr-concern-#{k}:#{v}" }.join + payload_light.map { |k, v| ";--sgr-payload-#{k}:#{v}" }.join +
        ";--sgr-high-chevron-a:#{light_roles[:ink]};--sgr-high-chevron-b:#{light_roles[:muted]};--sgr-high-chevron-label:#{light_roles[:paper]}"
      dark = dark_roles.map { |k, v| "--sgr-#{k}:#{v}" }.join(';') + concern_dark.map { |k, v| ";--sgr-concern-#{k}:#{v}" }.join + payload_dark.map { |k, v| ";--sgr-payload-#{k}:#{v}" }.join +
        ";--sgr-high-chevron-a:#{dark_roles[:secondary]};--sgr-high-chevron-b:#{dark_roles[:rule]};--sgr-high-chevron-label:#{dark_roles[:ink]}"
      <<~CSS
        ##{@id}{#{@d.theme == :dark ? dark : light};--sgr-node-radius:#{@d.style_profile.node_radius};--sgr-node-inset:#{@d.style_profile.node_inset};--sgr-border-width:#{@d.style_profile.border_width};--sgr-emphasis-width:#{@d.style_profile.emphasis_width};color:var(--sgr-ink);font-family:Geist,'Helvetica Neue',Arial,sans-serif}
        #{@d.theme == :auto ? "@media(prefers-color-scheme:dark){##{@id}{#{dark}}} [data-theme=dark] ##{@id},[data-sw-theme=dark] ##{@id},.dark ##{@id}{#{dark}} [data-theme=light] ##{@id},html:not(.dark)[data-sw-theme=light] ##{@id}{#{light}}" : ''}
        ##{@id} text{fill:var(--sgr-ink);font-size:#{BODY_TEXT_SIZE}px}
        ##{@id} .sgr-title{font-family:#{@d.style_profile.heading_family};font-size:30px;font-weight:#{@d.style_profile.heading_weight}}
        ##{@id} .sgr-name{font-weight:600}
        ##{@id} .sgr-detail,##{@id} .sgr-label{fill:var(--sgr-muted);font-size:12px}
        ##{@id} .sgr-invoke{font-family:'Geist Mono',ui-monospace,monospace;fill:var(--sgr-muted);font-size:12px}
        ##{@id} .sgr-scope{fill:var(--sgr-muted);font-size:12px}
        ##{@id} .sgr-owner-status{font-family:'Geist Mono',ui-monospace,monospace;fill:var(--sgr-accent);font-size:10px;font-weight:600;letter-spacing:.06em}
        ##{@id} .sgr-rule-kind{font-family:'Geist Mono',ui-monospace,monospace;fill:var(--sgr-accent);font-size:11px;font-weight:600;letter-spacing:.04em}
        ##{@id} .sgr-rule-label{font-size:13px;font-weight:600}
        ##{@id} .sgr-rule-owner{fill:var(--sgr-muted);font-size:12px}
        ##{@id} .sgr-zone{fill:var(--sgr-muted);font-size:12px;font-weight:600}
        ##{@id} .sgr-event-title{font-family:#{@d.style_profile.heading_family};font-size:18px}
        ##{@id} .sgr-event-detail{fill:var(--sgr-muted);font-size:14px}
        ##{@id} .sgr-date{font-family:'Geist Mono',ui-monospace,monospace;fill:var(--sgr-muted);font-size:12px}
        ##{@id} .sgr-frame-operator,##{@id} .sgr-frame-guard{font-family:'Geist Mono',ui-monospace,monospace;font-size:12px;fill:var(--sgr-muted)}
        ##{@id} .sgr-frame-operator{font-weight:600}
        ##{@id} .sgr-state-label,##{@id} .sgr-state-detail{font-family:'Geist Mono',ui-monospace,monospace;font-size:12px;fill:var(--sgr-muted)}
        ##{@id} .sgr-dependency-meta{font-family:'Geist Mono',ui-monospace,monospace;font-size:10px;fill:var(--sgr-muted)}
        ##{@id} .sgr-fan-in{font-family:'Geist Mono',ui-monospace,monospace;font-size:8px;fill:var(--sgr-muted)}
        ##{@id} .sgr-cycle-label{font-family:'Geist Mono',ui-monospace,monospace;font-size:8px;font-weight:600;letter-spacing:.06em;fill:var(--sgr-accent)}
        ##{@id} .sgr-deployment-zone,##{@id} .sgr-infrastructure-tag,##{@id} .sgr-replicas{font-family:'Geist Mono',ui-monospace,monospace;font-size:8px;fill:var(--sgr-muted)}
        ##{@id} .sgr-deployment-zone{font-weight:600;letter-spacing:.08em}
        ##{@id} .sgr-infrastructure-tag{font-weight:600;letter-spacing:.04em}
        ##{@id} .sgr-artifact-name{font-size:12px}
        ##{@id} .sgr-artifact-version,##{@id} .sgr-network-label{font-family:'Geist Mono',ui-monospace,monospace;fill:var(--sgr-muted)}
        ##{@id} .sgr-artifact-version{font-size:9px}
        ##{@id} .sgr-network-label{font-size:8px}
        ##{@id} .sgr-it-eyebrow,##{@id} .sgr-it-phase,##{@id} .sgr-it-handoff-label{font-family:'Geist Mono',ui-monospace,monospace;font-weight:600;letter-spacing:.08em}
        ##{@id} .sgr-it-eyebrow{fill:var(--sgr-muted);font-size:10px;letter-spacing:.12em}
        ##{@id} .sgr-it-subtitle{fill:var(--sgr-muted);font-size:14px}
        ##{@id} .sgr-it-phase{fill:var(--sgr-muted);font-size:9px;letter-spacing:.14em}
        ##{@id} .sgr-it-system-name{font-size:14px;font-weight:600}
        ##{@id} .sgr-it-system-detail{fill:var(--sgr-muted);font-size:12px}
        ##{@id} .sgr-it-pain-detail{fill:var(--sgr-accent);font-size:12px}
        ##{@id} .sgr-it-handoff-label{font-size:9px}
        ##{@id} .sgr-it-crosscut-name{font-size:14px;font-weight:600}
        ##{@id} .sgr-it-crosscut-detail{fill:var(--sgr-muted);font-size:12px}
        ##{@id} .sgr-it-legend-label{fill:var(--sgr-muted);font-size:10px}
        ##{@id} .sgr-high-phase,##{@id} .sgr-high-role,##{@id} .sgr-high-detail,##{@id} .sgr-high-legend{font-family:'Geist Mono',ui-monospace,monospace}
        ##{@id} .sgr-high-phase{fill:var(--sgr-high-chevron-label);font-size:12px;font-weight:600;letter-spacing:.14em}
        ##{@id} .sgr-high-role{fill:var(--sgr-muted);font-size:12px;font-weight:600;letter-spacing:.04em}
        ##{@id} .sgr-high-name{font-size:14px;font-weight:600}
        ##{@id} .sgr-high-detail{fill:var(--sgr-muted);font-size:12px}
        ##{@id} .sgr-high-concern{fill:var(--sgr-high-chevron-label);font-family:'Geist Mono',ui-monospace,monospace;font-size:12px;font-weight:600;letter-spacing:.14em}
        ##{@id} .sgr-high-cluster{fill:var(--sgr-muted);font-size:12px;font-weight:600}
        ##{@id} .sgr-high-legend{fill:var(--sgr-muted);font-size:12px}
        ##{@id} .sgr-tree-name{font-size:12px;font-weight:600}
        ##{@id} .sgr-tree-detail{font-family:'Geist Mono',ui-monospace,monospace;fill:var(--sgr-muted);font-size:9px}
        ##{@id} .sgr-nested-label{font-family:'Geist Mono',ui-monospace,monospace;fill:var(--sgr-muted);font-size:8px;font-weight:600;letter-spacing:.14em}
        ##{@id} .sgr-layer-index,##{@id} .sgr-layer-detail,##{@id} .sgr-layer-axis{font-family:'Geist Mono',ui-monospace,monospace;fill:var(--sgr-muted)}
        ##{@id} .sgr-layer-index{font-size:9px;font-weight:600;letter-spacing:.08em}
        ##{@id} .sgr-layer-name{font-size:15px;font-weight:600}
        ##{@id} .sgr-layer-detail{font-size:10px}
        ##{@id} .sgr-layer-axis{font-size:9px;font-weight:600;letter-spacing:.08em}
        ##{@id} .sgr-pyramid-label{font-size:12px;font-weight:600}
        ##{@id} .sgr-pyramid-value{font-family:'Geist Mono',ui-monospace,monospace;font-size:10px;fill:var(--sgr-muted)}
        ##{@id} .sgr-medallion-title{font-size:14px;font-weight:600}
        ##{@id} .sgr-medallion-field-label,##{@id} .sgr-medallion-promotion,##{@id} .sgr-medallion-path-tag{font-family:'Geist Mono',ui-monospace,monospace;font-weight:600;letter-spacing:.08em}
        ##{@id} .sgr-medallion-field-label{font-size:8px;fill:var(--sgr-muted)}
        ##{@id} .sgr-medallion-field-value{font-size:11px;fill:var(--sgr-muted)}
        ##{@id} .sgr-medallion-example{font-size:11px}
        ##{@id} .sgr-medallion-promotion{font-size:10px}
        ##{@id} .sgr-medallion-path-tag{font-size:8px}
        ##{@id} .sgr-medallion-path-title{font-size:11px;font-weight:600}
        ##{@id} .sgr-medallion-path-detail{font-size:10px;fill:var(--sgr-muted)}
        ##{@id} .sgr-workflow-stage,##{@id} .sgr-workflow-lane,##{@id} .sgr-workflow-key,##{@id} .sgr-workflow-detail,##{@id} .sgr-workflow-tool,##{@id} .sgr-workflow-trigger-label,##{@id} .sgr-workflow-legend{font-family:'Geist Mono',ui-monospace,monospace}
        ##{@id} .sgr-workflow-stage{fill:var(--sgr-muted);font-size:12px;font-weight:600;letter-spacing:.08em}
        ##{@id} .sgr-workflow-lane{fill:var(--sgr-muted);font-size:12px;font-weight:600;letter-spacing:.08em}
        ##{@id} .sgr-workflow-key{font-size:12px;font-weight:700}
        ##{@id} .sgr-workflow-card-name{font-size:14px;font-weight:600}
        ##{@id} .sgr-workflow-detail,##{@id} .sgr-workflow-tool{fill:var(--sgr-muted);font-size:12px}
        ##{@id} .sgr-workflow-trigger-label{fill:var(--sgr-muted);font-size:12px;font-weight:600;letter-spacing:.06em}
        ##{@id} .sgr-workflow-legend{fill:var(--sgr-muted);font-size:12px}
        ##{@id} .sgr-workflow-payload-text{fill:#fff;font-family:'Geist Mono',ui-monospace,monospace;font-size:12px;font-weight:700}
        ##{@id} .sgr-data-flow-step,##{@id} .sgr-data-flow-role,##{@id} .sgr-data-flow-key,##{@id} .sgr-data-flow-tool,##{@id} .sgr-data-flow-detail,##{@id} .sgr-data-flow-payload,##{@id} .sgr-data-flow-route-label,##{@id} .sgr-data-flow-legend{font-family:'Geist Mono',ui-monospace,monospace}
        ##{@id} .sgr-data-flow-step{fill:var(--sgr-muted);font-size:12px;font-weight:600}
        ##{@id} .sgr-data-flow-step.sgr-data-flow-step-focal{fill:var(--sgr-paper)}
        ##{@id} .sgr-data-flow-role{fill:var(--sgr-muted);font-size:12px;font-weight:600}
        ##{@id} .sgr-data-flow-key{font-size:12px;font-weight:700}
        ##{@id} .sgr-data-flow-name{font-size:14px;font-weight:600}
        ##{@id} .sgr-data-flow-detail-title{font-size:12px;font-weight:600}
        ##{@id} .sgr-data-flow-tool{fill:var(--sgr-muted);font-size:12px}
        ##{@id} .sgr-data-flow-detail{fill:var(--sgr-muted);font-size:#{Layout::DataFlow::DETAIL_TEXT_SIZE}px}
        ##{@id} .sgr-data-flow-payload{fill:#fff;font-size:12px;font-weight:700}
        ##{@id} .sgr-data-flow-route-label{fill:var(--sgr-accent);font-size:12px;font-weight:700;letter-spacing:.08em}
        ##{@id} .sgr-data-flow-legend{fill:var(--sgr-muted);font-size:12px}
        ##{@id} .sgr-integration-zone{fill:var(--sgr-ink);fill-opacity:.025;stroke:var(--sgr-rule);stroke-width:1}
        ##{@id} .sgr-security-eyebrow,##{@id} .sgr-security-subtle,##{@id} .sgr-security-role-code,##{@id} .sgr-security-hint,##{@id} .sgr-security-legend{font-family:'Geist Mono',ui-monospace,monospace}
        ##{@id} .sgr-security-eyebrow{fill:var(--sgr-muted);font-size:9px;font-weight:700;letter-spacing:.14em}
        ##{@id} .sgr-security-subtle{fill:var(--sgr-muted);font-size:8px;font-weight:600;letter-spacing:.10em}
        ##{@id} .sgr-security-role{fill:var(--sgr-paper);font-size:11px;font-weight:600}
        ##{@id} .sgr-security-role-code{fill:var(--sgr-paper);font-size:9px;opacity:.85}
        ##{@id} .sgr-security-component{font-size:11px;font-weight:600}
        ##{@id} .sgr-security-hint{fill:var(--sgr-muted);font-size:8px;font-weight:600;letter-spacing:.08em}
        ##{@id} .sgr-security-cell{stroke:var(--sgr-rule);stroke-width:1}
        ##{@id} .sgr-security-admin{fill:var(--sgr-secondary);stroke:var(--sgr-ink)}
        ##{@id} .sgr-security-write{fill:var(--sgr-paper);stroke:var(--sgr-rule)}
        ##{@id} .sgr-security-read{fill:var(--sgr-tint);stroke:var(--sgr-muted)}
        ##{@id} .sgr-security-deny{fill:var(--sgr-paper);stroke:var(--sgr-rule);stroke-dasharray:4 3}
        ##{@id} .sgr-security-unknown{fill:var(--sgr-secondary);stroke:var(--sgr-muted);stroke-dasharray:1 3}
        ##{@id} .sgr-security-focal{fill:var(--sgr-tint);stroke:var(--sgr-accent);stroke-width:2;stroke-dasharray:none}
        ##{@id} .sgr-security-value{font-size:10px;font-weight:600}
        ##{@id} .sgr-security-focal-value{fill:var(--sgr-accent)}
        ##{@id} .sgr-security-note{fill:var(--sgr-accent);font-size:8px}
        ##{@id} .sgr-security-legend{fill:var(--sgr-muted);font-size:9px;font-weight:600;letter-spacing:.08em}
        ##{@id} .sgr-integration-card{fill:var(--sgr-paper);stroke:var(--sgr-ink);stroke-width:1}
        ##{@id} .sgr-integration-side{fill:var(--sgr-secondary);fill-opacity:.45;stroke:var(--sgr-rule)}
        ##{@id} .sgr-integration-focal{fill:var(--sgr-tint);fill-opacity:1;stroke:var(--sgr-accent);stroke-width:1.5}
        ##{@id} .sgr-integration-layer{fill:var(--sgr-secondary);fill-opacity:.42;stroke:var(--sgr-rule)}
        ##{@id} .sgr-integration-zone-label,##{@id} .sgr-integration-role,##{@id} .sgr-integration-kind,##{@id} .sgr-integration-protocol,##{@id} .sgr-integration-legend{font-family:'Geist Mono',ui-monospace,monospace}
        ##{@id} .sgr-integration-zone-label{fill:var(--sgr-muted);font-size:12px;font-weight:600;letter-spacing:.12em}
        ##{@id} .sgr-integration-name{font-size:14px;font-weight:600}
        ##{@id} .sgr-integration-detail{fill:var(--sgr-muted);font-size:12px}
        ##{@id} .sgr-integration-role,##{@id} .sgr-integration-kind{fill:var(--sgr-muted);font-size:12px;font-weight:600;letter-spacing:.6px}
        ##{@id} .sgr-integration-protocol{fill:var(--sgr-muted);font-size:12px;font-weight:600;letter-spacing:.7px}
        ##{@id} .sgr-integration-legend{fill:var(--sgr-muted);font-size:12px}
        ##{@id} .sgr-gantt-date,##{@id} .sgr-gantt-caption,##{@id} .sgr-gantt-phase,##{@id} .sgr-gantt-marker-label{font-family:'Geist Mono',ui-monospace,monospace;fill:var(--sgr-muted)}
        ##{@id} .sgr-gantt-date{font-size:8px}
        ##{@id} .sgr-gantt-caption{font-size:9px}
        ##{@id} .sgr-gantt-phase{font-size:9px;font-weight:600;letter-spacing:.14em}
        ##{@id} .sgr-gantt-marker-label{font-size:9px;font-weight:600}
        ##{@id} .sgr-gantt-task-label{font-size:11px;font-weight:600}
        ##{@id} .sgr-gantt-bar-label{font-size:10px;font-weight:600}
        ##{@id} .sgr-gantt-point-label{font-size:10px;font-weight:600;fill:var(--sgr-accent)}
        ##{@id} .sgr-kanban-column-label{font-size:12px;font-weight:600}
        ##{@id} .sgr-kanban-count,##{@id} .sgr-kanban-card-meta{font-family:'Geist Mono',ui-monospace,monospace;fill:var(--sgr-muted)}
        ##{@id} .sgr-kanban-count{font-size:8px;font-weight:600}
        ##{@id} .sgr-kanban-card-title{font-size:12px;font-weight:600}
        ##{@id} .sgr-kanban-card-meta{font-size:9px}
        ##{@id} .sgr-journey-eyebrow,##{@id} .sgr-journey-persona,##{@id} .sgr-journey-level,##{@id} .sgr-journey-row-label,##{@id} .sgr-journey-touchpoint,##{@id} .sgr-journey-pain,##{@id} .sgr-journey-caption,##{@id} .sgr-journey-legend,##{@id} .sgr-story-eyebrow,##{@id} .sgr-story-persona,##{@id} .sgr-story-release,##{@id} .sgr-story-meta,##{@id} .sgr-story-tag,##{@id} .sgr-story-legend{font-family:'Geist Mono',ui-monospace,monospace}
        ##{@id} .sgr-journey-eyebrow,##{@id} .sgr-story-eyebrow{fill:var(--sgr-muted);font-size:12px;font-weight:600;letter-spacing:.14em}
        ##{@id} .sgr-journey-persona,##{@id} .sgr-story-persona{fill:var(--sgr-muted);font-size:12px;font-weight:600;letter-spacing:.08em}
        ##{@id} .sgr-journey-stage,##{@id} .sgr-story-activity{font-size:14px;font-weight:600}
        ##{@id} .sgr-journey-level,##{@id} .sgr-journey-row-label{fill:var(--sgr-muted);font-size:12px;letter-spacing:.14em}
        ##{@id} .sgr-journey-action{font-size:14px}
        ##{@id} .sgr-journey-touchpoint{fill:var(--sgr-muted);font-size:12px}
        ##{@id} .sgr-journey-pain{fill:var(--sgr-accent);font-size:12px}
        ##{@id} .sgr-journey-caption,##{@id} .sgr-journey-legend,##{@id} .sgr-story-legend{fill:var(--sgr-muted);font-size:12px}
        ##{@id} .sgr-story-release{fill:var(--sgr-muted);font-size:12px;font-weight:600;letter-spacing:.14em}
        ##{@id} .sgr-story-step{font-size:14px}
        ##{@id} .sgr-story-title{font-size:14px;font-weight:600}
        ##{@id} .sgr-story-meta{fill:var(--sgr-muted);font-size:12px}
        ##{@id} .sgr-story-tag{fill:var(--sgr-accent);font-size:12px;font-weight:700;letter-spacing:.08em}
        ##{@id} .sgr-er-tag,##{@id} .sgr-er-key,##{@id} .sgr-er-field,##{@id} .sgr-er-cardinality{font-family:'Geist Mono',ui-monospace,monospace}
        ##{@id} .sgr-db-tag,##{@id} .sgr-db-schema-label,##{@id} .sgr-db-sql-type,##{@id} .sgr-db-constraint,##{@id} .sgr-db-index-eyebrow,##{@id} .sgr-db-index,##{@id} .sgr-db-action{font-family:'Geist Mono',ui-monospace,monospace}
        ##{@id} .sgr-db-schema-label{fill:var(--sgr-muted);font-size:#{Layout::DatabaseSchema::METADATA_TEXT_SIZE}px;font-weight:600;letter-spacing:.14em}
        ##{@id} .sgr-db-tag,##{@id} .sgr-db-index-eyebrow{fill:var(--sgr-muted);font-size:#{Layout::DatabaseSchema::METADATA_TEXT_SIZE}px;font-weight:600;letter-spacing:.08em}
        ##{@id} .sgr-db-table-name,##{@id} .sgr-db-column-name{font-size:#{Layout::DatabaseSchema::PRIMARY_TEXT_SIZE}px}
        ##{@id} .sgr-db-table-name{font-weight:600}
        ##{@id} .sgr-db-sql-type,##{@id} .sgr-db-index{fill:var(--sgr-muted);font-size:#{Layout::DatabaseSchema::METADATA_TEXT_SIZE}px}
        ##{@id} .sgr-db-overflow{fill:var(--sgr-muted);font-size:#{Layout::DatabaseSchema::METADATA_TEXT_SIZE}px}
        ##{@id} .sgr-db-constraint,##{@id} .sgr-db-action{fill:var(--sgr-muted);font-size:#{Layout::DatabaseSchema::METADATA_TEXT_SIZE}px;font-weight:600}
        ##{@id} .sgr-db-action-cascade{fill:var(--sgr-accent)}
        ##{@id} .sgr-uml-stereotype,##{@id} .sgr-uml-member,##{@id} .sgr-uml-multiplicity,##{@id} .sgr-uml-relation-label,##{@id} .sgr-uml-legend{font-family:'Geist Mono',ui-monospace,monospace}
        ##{@id} .sgr-uml-name{font-size:#{Layout::UMLClass::PRIMARY_TEXT_SIZE}px;font-weight:600}
        ##{@id} .sgr-uml-abstract{font-style:italic}
        ##{@id} .sgr-uml-focal{fill:var(--sgr-accent)}
        ##{@id} .sgr-quadrant-axis{font-family:'Geist Mono',ui-monospace,monospace;fill:var(--sgr-muted);font-size:#{Layout::Quadrant::AXIS_TEXT_SIZE}px;font-weight:400;letter-spacing:.18em}
        ##{@id} .sgr-quadrant-region{font-family:'Geist Mono',ui-monospace,monospace;fill:var(--sgr-muted);font-size:#{Layout::Quadrant::AXIS_TEXT_SIZE}px;font-weight:600;letter-spacing:.12em}
        ##{@id} .sgr-quadrant-item{font-size:#{Layout::Quadrant::POINT_TEXT_SIZE}px}
        ##{@id} .sgr-quadrant-focal{fill:var(--sgr-accent);font-weight:600}
        ##{@id} .sgr-quadrant-caption{fill:var(--sgr-muted);font-size:#{Layout::Quadrant::CAPTION_TEXT_SIZE}px}
        ##{@id} .sgr-venn-set-label{font-size:#{Layout::Venn::SET_TEXT_SIZE}px;font-weight:600}
        ##{@id} .sgr-venn-set-subtitle{font-family:'Geist Mono',ui-monospace,monospace;fill:var(--sgr-muted);font-size:#{Layout::Venn::SUBTITLE_TEXT_SIZE}px;letter-spacing:.08em}
        ##{@id} .sgr-venn-region-label{font-size:#{Layout::Venn::REGION_TEXT_SIZE}px;font-weight:600}
        ##{@id} .sgr-venn-focal{fill:var(--sgr-accent)}
        ##{@id} .sgr-venn-caption{fill:var(--sgr-muted);font-size:14px}
        ##{@id} .sgr-loop-station-name{font-size:#{Layout::Loop::PRIMARY_TEXT_SIZE}px;font-weight:600}
        ##{@id} .sgr-loop-station-detail,##{@id} .sgr-loop-write-label{fill:var(--sgr-muted);font-size:#{Layout::Loop::METADATA_TEXT_SIZE}px}
        ##{@id} .sgr-loop-write-label{font-family:'Geist Mono',ui-monospace,monospace;font-weight:600;letter-spacing:.06em}
        ##{@id} .sgr-loop-focal{fill:var(--sgr-accent)}
        ##{@id} .sgr-loop-hub-name{fill:var(--sgr-paper);font-size:#{Layout::Loop::PRIMARY_TEXT_SIZE}px;font-weight:600}
        ##{@id} .sgr-loop-hub-detail{fill:var(--sgr-paper);font-size:#{Layout::Loop::METADATA_TEXT_SIZE}px;opacity:.82}
        ##{@id} .sgr-fishbone-effect{font-size:#{Layout::Fishbone::EFFECT_TEXT_SIZE}px;font-weight:600}
        ##{@id} .sgr-fishbone-category{font-size:#{Layout::Fishbone::CATEGORY_TEXT_SIZE}px;font-weight:600}
        ##{@id} .sgr-fishbone-factor{fill:var(--sgr-muted);font-family:'Geist Mono',ui-monospace,monospace;font-size:#{Layout::Fishbone::FACTOR_TEXT_SIZE}px}
        ##{@id} .sgr-wardley-component{font-size:#{Layout::Wardley::POINT_TEXT_SIZE}px;font-weight:600}
        ##{@id} .sgr-wardley-band,##{@id} .sgr-wardley-axis-copy,##{@id} .sgr-wardley-legend{font-family:'Geist Mono',ui-monospace,monospace;fill:var(--sgr-muted);font-size:#{Layout::Wardley::AXIS_TEXT_SIZE}px;letter-spacing:.14em}
        ##{@id} .sgr-wardley-band{font-weight:600}
        ##{@id} .sgr-wardley-caption{fill:var(--sgr-muted);font-size:#{Layout::Wardley::CAPTION_TEXT_SIZE}px}
        ##{@id} .sgr-uml-member{font-size:#{Layout::UMLClass::MEMBER_TEXT_SIZE}px}
        ##{@id} .sgr-uml-stereotype,##{@id} .sgr-uml-multiplicity,##{@id} .sgr-uml-legend{fill:var(--sgr-muted);font-size:#{Layout::UMLClass::METADATA_TEXT_SIZE}px}
        ##{@id} .sgr-uml-stereotype,##{@id} .sgr-uml-multiplicity{font-weight:600}
        ##{@id} .sgr-uml-member,##{@id} .sgr-uml-stereotype,##{@id} .sgr-uml-multiplicity,##{@id} .sgr-uml-legend{font-family:'Geist Mono',ui-monospace,monospace}
        ##{@id} .sgr-uml-name{font-size:#{Layout::UMLClass::PRIMARY_TEXT_SIZE}px;font-weight:600}
        ##{@id} .sgr-uml-abstract{font-style:italic}
        ##{@id} .sgr-uml-member{font-size:#{Layout::UMLClass::MEMBER_TEXT_SIZE}px}
        ##{@id} .sgr-uml-stereotype,##{@id} .sgr-uml-multiplicity,##{@id} .sgr-uml-legend{fill:var(--sgr-muted);font-size:#{Layout::UMLClass::METADATA_TEXT_SIZE}px}
        ##{@id} .sgr-uml-focal{fill:var(--sgr-accent)}
        ##{@id} .sgr-er-tag{fill:var(--sgr-muted);font-size:8px;font-weight:700;letter-spacing:.12em}
        ##{@id} .sgr-er-name{font-size:12px;font-weight:600}
        ##{@id} .sgr-er-focal{fill:var(--sgr-accent)}
        ##{@id} .sgr-er-key{fill:var(--sgr-muted);font-size:10px;font-weight:700}
        ##{@id} .sgr-er-field{font-size:10px}
        ##{@id} .sgr-er-cardinality{fill:var(--sgr-muted);font-size:8px;font-weight:600}
        ##{@id} .sgr-er-label{fill:var(--sgr-muted);font-size:10px}
        ##{@id} .sgr-emphasis{fill:var(--sgr-accent)}
      CSS
    end

    def readable_display_scale
      metadata_scale = READABLE_METADATA_SIZE.fdiv(MINIMUM_TEXT_SIZE.fetch(@d.type))
      [READABLE_BODY_SIZE.fdiv(BODY_TEXT_SIZE), metadata_scale].max
    end

    def concern_palettes
      palettes = {
        editorial: [{ security: '#9f3f3b', quality: '#4f718e', product: '#697d37', analysis: '#98781d' },
                    { security: '#ff9a92', quality: '#9fc9ed', product: '#b8d375', analysis: '#f0ce68' }],
        ruby: [{ security: '#ad1733', quality: '#526f8a', product: '#667b38', analysis: '#94741b' },
               { security: '#ff93a6', quality: '#a8c9e8', product: '#bdd77c', analysis: '#f0cf70' }],
        blueprint: [{ security: '#a34542', quality: '#145da0', product: '#58743a', analysis: '#896d1f' },
                    { security: '#ff9c96', quality: '#88c8ff', product: '#b4d77b', analysis: '#f2d476' }],
        mono: [{ security: '#3d3d3d', quality: '#5d5d5d', product: '#737373', analysis: '#202020' },
               { security: '#f5f5f5', quality: '#d8d8d8', product: '#bdbdbd', analysis: '#ffffff' }],
        minimal: [{ security: '#9f1239', quality: '#7f1d1d', product: '#9a4055', analysis: '#18212f' },
                  { security: '#fda4af', quality: '#fecdd3', product: '#f9a8b8', analysis: '#f8fafc' }]
      }
      palettes.fetch(@d.style)
    end

    def accessible_description
      return data_flow_description if @d.type == :data_flow
      return dp_integration_description if @d.type == :dp_integration
      return dp_security_matrix_description if @d.type == :dp_security_matrix
      return er_description if @d.type == :er
      return db_schema_description if @d.type == :db_schema
      return uml_class_description if @d.type == :uml_class
      return quadrant_description if @d.type == :quadrant
      return venn_description if @d.type == :venn
      return loop_description if @d.type == :loop
      return fishbone_description if @d.type == :fishbone
      return wardley_description if @d.type == :wardley
      return planning_board_description if %i[gantt kanban].include?(@d.type)
      return journey_family_description if %i[journey story_map].include?(@d.type)
      return @d.description if @d.description && !%i[org_chart swimlane process].include?(@d.type)
      return workflow_description if %i[swimlane process].include?(@d.type)
      if @d.type == :tree
        relationships = @d.tree_nodes.map do |item|
          parent = @d.tree_nodes.find { |candidate| candidate.id == item.parent_id }
          "#{item.label}#{item.detail ? ": #{item.detail}" : ''}#{parent ? ", child of #{parent.label}" : ', root'}#{item.focal ? ', focal' : ''}."
        end.join(' ')
        return "Tree hierarchy. #{relationships}"
      end
      if @d.type == :nested
        return "Containment chain. Outer to inner: #{@d.containment_scopes.map(&:label).join(' contains ')}. Innermost: #{@d.containment_scopes.last.label}."
      end
      if @d.type == :layers
        rows = @d.layers.map do |item|
          "#{item.index}: #{item.label}#{item.detail ? ", #{item.detail}" : ''}#{item.focal ? ', focal' : ''}"
        end.join('; ')
        return "Layer stack. #{@d.axis} points #{@d.indicator}. Top to bottom: #{rows}."
      end
      if @d.type == :pyramid
        levels = @d.levels.map do |item|
          quantity = @d.mode == :measured ? ", #{item.from} to #{item.to} #{@d.unit}" : ''
          "#{item.label}#{item.detail ? ": #{item.detail}" : ''}#{quantity}#{item.focal ? ', focal' : ''}"
        end.join('; ')
        meaning = @d.mode == :hierarchy ? 'Ordinal hierarchy; taper shows rank and does not encode quantity.' : 'Measured boundaries encode declared quantities.'
        return "#{@d.orientation.to_s.capitalize}. #{meaning} Declaration order: #{levels}."
      end
      if @d.type == :medallion
        tiers = @d.tiers.map do |item|
          roles = [item.concern && "#{item.concern} concern", item.focal ? 'focal' : nil, item.archive ? 'archive' : nil].compact
          "#{item.label}: bucket #{item.bucket}; tool #{item.tool}; format #{item.format}; writer #{item.writer}; examples #{item.examples.join(', ')}#{roles.empty? ? '' : "; #{roles.join(', ')}"}"
        end.join('. ')
        promotions = @d.promotions.map { |item| "#{item.from} to #{item.to}: #{item.label}" }.join('; ')
        paths = @d.write_paths.map { |item| "#{item.tag}: #{item.title}, #{item.detail}#{item.concern ? ", #{item.concern} concern" : ''}" }.join('; ')
        return "Medallion storage tiers, left to right. #{tiers}. Promotions: #{promotions}.#{paths.empty? ? '' : " Write paths: #{paths}."}"
      end
      if @d.type == :high_level
        phases = @d.phases.map do |phase|
          sources = @d.sources.select { |item| item.phase == phase.id }.map do |item|
            "#{item.label}, #{item.source_type} source#{item.detail ? ": #{item.detail}" : ''}"
          end
          components = @d.components.select { |item| item.phase == phase.id }.map do |item|
            "#{item.label}, #{item.role}#{item.focal ? ', focal' : ''}#{item.detail ? ": #{item.detail}" : ''}"
          end
          "#{phase.label}: #{(sources + components).join('; ')}."
        end.join(' ')
        connections = @s.routes.reject { |route| route.style == :trigger }.map do |route|
          item = route.edge
          from = (@d.sources + @d.components).find { |node| node.id == item.from }.label
          to = @d.components.find { |node| node.id == item.to }.label
          "#{from} to #{to}: #{route.style}"
        end.join('; ')
        orchestration = if @d.orchestration
          names = @d.orchestration.targets.map { |id| @d.components.find { |item| item.id == id }.label }
          triggers = @s.routes.select { |route| route.style == :trigger }.map do |route|
            target = @d.components.find { |item| item.id == route.edge.to }.label
            "#{@d.orchestration.label} to #{target}: #{route.style}"
          end.join('; ')
          "#{@d.orchestration.label} orchestrates #{names.join(', ')}. Orchestration routes: #{triggers}."
        end
        crosscuts = @d.crosscuts.map do |item|
          "#{item.concern} concern: #{item.label}#{item.detail ? ": #{item.detail}" : ''}."
        end.join(' ')
        return "High-level data stack. Cluster: #{@d.cluster}. #{phases} Data paths: #{connections}. #{orchestration} #{crosscuts}".strip
      end
      if @d.type == :it_state
        phases = @d.phases.map do |phase|
          systems = @d.nodes.select { |node| node.zone == phase.id }.map do |node|
            state = node.kind == :standard ? '' : ", #{node.kind.to_s.tr('_', ' ')}"
            "#{node.label}#{state}#{node.detail ? ": #{node.detail}" : ''}"
          end
          "#{phase.label} contains #{systems.join('; ')}."
        end.join(' ')
        handoffs = @d.edges.map do |item|
          from = @d.nodes.find { |node| node.id == item.from }
          to = @d.nodes.find { |node| node.id == item.to }
          qualifiers = [@d.effective_handoff_style(item), item.dashed ? 'dashed' : nil].compact.join(', ')
          "#{from.label} to #{to.label}: #{item.label}, #{qualifiers}."
        end.join(' ')
        crosscuts = @d.crosscuts.map do |item|
          "Cross-cutting service: #{item.label}#{item.detail ? ": #{item.detail}" : ''}."
        end.join(' ')
        return "IT current-state. #{phases} Hand-offs: #{handoffs} #{crosscuts}".strip
      end
      if @d.type == :sequence
        actors = @d.nodes.map { |node| "#{node.label}#{node.detail ? ": #{node.detail}" : ''}" }.join('; ')
        return "Sequence. Participants: #{actors}. #{sequence_description(@d.sequence_items)}"
      end
      if @d.type == :state
        names = @d.states.to_h { |state| [state.id, state.label] }
        state_list = @d.states.map { |state| "#{state.label}#{state.detail ? ": #{state.detail}" : ''}" }.join('; ')
        transition_list = @d.transitions.map do |item|
          "#{names.fetch(item.from)} to #{names.fetch(item.to)}: #{item.label}"
        end.join('; ')
        finals = @d.final_states.map { |id| names.fetch(id) }.join(', ')
        return "State machine. Initial: #{names.fetch(@d.initial_state)}. Final: #{finals}. States: #{state_list}. Transitions: #{transition_list}."
      end
      if @d.type == :dependency
        nodes = @d.nodes.map do |node|
          fan_in = @d.edges.count { |edge| edge.to == node.id }
          external = node.kind == :external ? ", external #{node.version} from #{node.registry}" : ''
          "#{node.label}, #{fan_in} dependents#{external}"
        end.join('; ')
        relationships = @d.edges.map do |edge|
          from = @d.nodes.find { |node| node.id == edge.from }.label
          to = @d.nodes.find { |node| node.id == edge.to }.label
          "#{from} depends on #{to}#{edge.cycle ? ' (cycle)' : ''}"
        end.join('; ')
        return "Dependency graph. Nodes: #{nodes}. Relationships: #{relationships}."
      end
      if @d.type == :deployment
        zones = @d.zones.map do |zone|
          members = @d.nodes.select { |node| node.zone == zone.id }.map do |node|
            replicas = "#{node.replicas} replica#{node.replicas == 1 ? '' : 's'}"
            artifacts = node.artifacts.map { |item| "#{item.name} #{item.version}" }.join(', ')
            "#{node.label} with #{replicas}: #{artifacts}"
          end
          "#{zone.label} contains #{members.join('; ')}."
        end.join(' ')
        paths = @d.edges.map do |edge|
          from = @d.nodes.find { |node| node.id == edge.from }
          to = @d.nodes.find { |node| node.id == edge.to }
          scope = from.zone == to.zone ? 'internal' : 'cross-zone'
          qualifiers = [scope, edge.dashed ? 'asynchronous' : nil, edge.emphasis ? 'focal' : nil].compact.join(', ')
          "#{from.label} to #{to.label} over #{edge.protocol}:#{edge.port}, #{qualifiers}."
        end.join(' ')
        return "Deployment. #{zones} Networks: #{paths}"
      end
      if @d.type == :timeline
        events = @s.events.map { |item| item[:event] }
        meaning = @s.axis[:mode] == :date ? 'Calendar dates with linear elapsed-day spacing.' : 'Ordered milestones; spacing does not measure time.'
        "#{meaning} #{events.map { |e| "#{e.date}: #{e.label}. #{e.detail}" }.join(' ')}"
      else
        nodes = @d.nodes.map do |node|
          role = @d.type == :flowchart && %i[start finish decision merge].include?(node.kind) ? "#{node.kind.to_s.capitalize}: " : ''
          ownership = if @d.type == :org_chart
            [node.invoke && "Invocation: #{node.invoke}", node.scope && "Scope: #{node.scope}", node.unavailable ? 'Setup needed' : nil].compact.join('. ')
          end
          ["#{role}#{node.label}#{node.detail ? ": #{node.detail}" : ''}", ownership].compact.reject(&:empty?).join('. ')
        end.join('; ')
        edges = @d.edges.map { |e| "#{@d.nodes.find { |n| n.id == e.from }.label} to #{@d.nodes.find { |n| n.id == e.to }.label}#{e.label ? ": #{e.label}" : ''}" }.join('; ')
        groups = @d.groups.map do |group|
          members = @d.nodes.select { |node| node.group == group.id }.map(&:label)
          "#{group.label} contains #{members.join(', ')}."
        end.join(' ')
        rules = @d.rules.map do |rule|
          owner = @d.nodes.find { |node| node.id == rule.owner }
          preposition = rule.kind == :escalation ? 'to' : 'by'
          "#{rule.kind.to_s.capitalize}: #{rule.label} #{preposition} #{owner.label}#{owner.invoke ? " (#{owner.invoke})" : ''}."
        end.join(' ')
        gaps = @d.setup_gaps.map do |gap|
          owner = @d.nodes.find { |node| node.id == gap.owner }
          "Setup gap: #{gap.label} for #{owner.label}#{owner.invoke ? " (#{owner.invoke})" : ''}."
        end.join(' ')
        generated = "#{@d.type.to_s.tr('_', ' ')}. #{nodes}. Connections: #{edges}. #{groups} #{rules} #{gaps}".strip
        [@d.description, generated].compact.join(' ')
      end
    end

    def sequence_description(items)
      name = ->(id) { @d.nodes.find { |node| node.id == id }.label }
      items.map do |item|
        case item
        when Edge
          "#{item.kind.to_s.capitalize} from #{name.call(item.from)} to #{name.call(item.to)}#{item.label ? ": #{item.label}" : ''}."
        when Activation
          "#{name.call(item.actor)} active: #{sequence_description(item.items)} End activation."
        when Fragment
          regions = item.regions.map { |region| "When #{region.guard}: #{sequence_description(region.items)}" }.join(' ')
          "#{ {alt: 'Alternatives', opt: 'Optional', loop: 'Repeat'}.fetch(item.operator) }: #{regions} End #{item.operator}."
        end
      end.join(' ')
    end

    def header_layout
      title_budget = %i[swimlane process].include?(@d.type) ? @s.width - 80 : [@s.width - 80, 720].min
      title_lines = Text.wrap(@d.title, title_budget, 30, font: @d.style_profile.heading_font)
      return { title_lines: title_lines, height: 48 + title_lines.size * 36 } unless @d.type == :it_state
      eyebrow_lines = @d.eyebrow ? Text.wrap(@d.eyebrow.upcase, [@s.width - 80, 720].min, 10, font: :mono) : []
      subtitle_lines = @d.subtitle ? Text.wrap(@d.subtitle, [@s.width - 80, 720].min, 14) : []
      title_y = eyebrow_lines.empty? ? 48 : 60
      subtitle_y = title_y + title_lines.size * 36
      bottom = subtitle_lines.empty? ? subtitle_y : subtitle_y + subtitle_lines.size * 20
      {
        title_lines: title_lines, eyebrow_lines: eyebrow_lines, subtitle_lines: subtitle_lines,
        eyebrow_y: 24, title_y: title_y, subtitle_y: subtitle_y, height: bottom + 16
      }
    end

    def draw_tree
      @s.tree_connectors.each do |connector|
        parent_id = connector[:parent_id]
        a, b = connector[:stem]
        add %(<line data-sgr-tree-stem="#{esc(parent_id)}" x1="#{a[0]}" y1="#{a[1]}" x2="#{b[0]}" y2="#{b[1]}" stroke="var(--sgr-muted)" stroke-width="1"/> )
        a, b = connector[:bus]
        add %(<line data-sgr-tree-bus="#{esc(parent_id)}" x1="#{a[0]}" y1="#{a[1]}" x2="#{b[0]}" y2="#{b[1]}" stroke="var(--sgr-muted)" stroke-width="1"/> )
        connector[:drops].each do |drop|
          a, b = drop[:points]
          add %(<line data-sgr-tree-drop="#{esc(drop[:child_id])}" x1="#{a[0]}" y1="#{a[1]}" x2="#{b[0]}" y2="#{b[1]}" stroke="var(--sgr-muted)" stroke-width="1"/> )
        end
      end
      @s.boxes.each do |box|
        item = box.node
        leaf = @d.tree_nodes.none? { |candidate| candidate.parent_id == item.id }
        fill = item.focal ? 'var(--sgr-tint)' : leaf ? 'var(--sgr-secondary)' : 'var(--sgr-paper)'
        stroke = item.focal ? 'var(--sgr-accent)' : leaf ? 'var(--sgr-muted)' : 'var(--sgr-ink)'
        rect(box.x, box.y, box.width, box.height, rx: 6, fill: fill, stroke: stroke,
             'stroke-width': leaf && !item.focal ? 0.8 : 1,
             'data-sgr-tree-node': item.id, 'data-sgr-tree-leaf': leaf, 'data-sgr-tree-focal': item.focal)
        text(item.label, box.center[0], box.y + (item.detail ? 21 : 25),
             class: "sgr-tree-name#{item.focal ? ' sgr-emphasis' : ''}", 'text-anchor': 'middle')
        text(item.detail, box.center[0], box.y + 39, class: 'sgr-tree-detail', 'text-anchor': 'middle') if item.detail
      end
    end

    def draw_nested
      @s.nested_scopes.each do |entry|
        item = entry[:scope]
        x, y, right, bottom = entry[:rect]
        focal = entry[:focal]
        rect(x, y, right - x, bottom - y, rx: 8,
             fill: focal ? 'var(--sgr-tint)' : 'var(--sgr-ink)', 'fill-opacity': focal ? 1 : 0.012 * entry[:strength],
             stroke: focal ? 'var(--sgr-accent)' : entry[:strength] == 1 ? 'var(--sgr-rule)' : 'var(--sgr-muted)',
             'stroke-opacity': focal ? 1 : [0.36 + entry[:strength] * 0.12, 0.86].min,
             'stroke-width': focal ? 1.2 : 1,
             'data-sgr-scope': item.id, 'data-sgr-scope-focal': focal,
             'data-sgr-inset-x': entry[:inset_x], 'data-sgr-inset-y': entry[:inset_y])
        lx, ly, lr, lb = entry[:label_rect]
        rect(lx, ly, lr - lx, lb - ly, fill: 'var(--sgr-paper)', 'data-sgr-scope-label-mask': item.id)
        text(entry[:label], lx + 8, ly + 11, class: "sgr-nested-label#{focal ? ' sgr-emphasis' : ''}")
      end
    end

    def draw_layers
      @s.layer_rows.each_with_index do |entry, row|
        item = entry[:layer]
        x, y, right, bottom = entry[:rect]
        fill = item.focal ? 'var(--sgr-tint)' : row.odd? ? 'var(--sgr-secondary)' : 'var(--sgr-paper)'
        stroke = item.focal ? 'var(--sgr-accent)' : 'var(--sgr-rule)'
        rect(x, y, right - x, bottom - y, rx: 0, fill: fill, stroke: stroke,
             'stroke-width': item.focal ? 1.2 : 1, 'data-sgr-layer': item.id,
             'data-sgr-layer-height': bottom - y, 'data-sgr-layer-focal': item.focal)
        text(item.index.upcase, entry[:index_x], y + 37, class: 'sgr-layer-index')
        text(item.label, entry[:name_x], y + 39, class: "sgr-layer-name#{item.focal ? ' sgr-emphasis' : ''}")
        text(item.detail, entry[:detail_x], y + 37, class: 'sgr-layer-detail', 'text-anchor': 'end') if item.detail
      end
      item = @s.direction_indicator
      y1, y2 = item[:direction] == :up ? [item[:bottom], item[:top]] : [item[:top], item[:bottom]]
      add %(<line data-sgr-indicator="#{item[:direction]}" x1="#{item[:x]}" y1="#{y1}" x2="#{item[:x]}" y2="#{y2}" stroke="var(--sgr-muted)" stroke-width="1" marker-end="url(##{@id}-arrow-sm)"/> )
      text(item[:label], item[:x] - 18, item[:center_y], class: 'sgr-layer-axis', 'text-anchor': 'middle',
           transform: "rotate(-90 #{item[:x] - 18} #{item[:center_y]})")
    end

    def draw_pyramid
      @s.pyramid_bands.each do |band|
        item = band[:level]
        fill = item.focal ? 'var(--sgr-tint)' : 'var(--sgr-secondary)'
        stroke = item.focal ? 'var(--sgr-accent)' : 'var(--sgr-rule)'
        points = band[:points].map { |point| point.join(',') }.join(' ')
        add %(<polygon #{attrs('data-sgr-pyramid-level': item.id, 'data-sgr-pyramid-focal': item.focal,
                              'data-sgr-boundary-from-width': band[:from_width], 'data-sgr-boundary-to-width': band[:to_width],
                              points: points, fill: fill, stroke: stroke, 'stroke-width': item.focal ? 1.4 : 1)}/>)
      end
      @s.pyramid_bands.each do |band|
        item = band[:level]
        if band[:outside]
          x1 = band[:anchor_x]
          x2 = Layout::Pyramid::LEFT + Layout::Pyramid::MAX_WIDTH + Layout::Pyramid::LEADER_GAP
          line(x1, band[:center_y], x2, band[:center_y], item.focal ? 'var(--sgr-accent)' : 'var(--sgr-muted)')
          rect(x2 + 4, band[:center_y] - 12, band[:label_width] + 16, 24, rx: 3, fill: 'var(--sgr-paper)',
               'data-sgr-pyramid-label-mask': item.id)
          text(band[:text], band[:label_x], band[:center_y] + 4, class: 'sgr-pyramid-label',
               'data-sgr-pyramid-label-placement': 'outside')
        else
          text(item.label, band[:label_x], band[:center_y] - (item.detail || @d.mode == :measured ? 3 : -4),
               class: "sgr-pyramid-label#{item.focal ? ' sgr-emphasis' : ''}", 'text-anchor': 'middle',
               'data-sgr-pyramid-label-placement': 'inside')
          value = @d.mode == :measured ? "#{item.from} → #{item.to} #{@d.unit}" : item.detail
          text(value, band[:label_x], band[:center_y] + 13, class: 'sgr-pyramid-value', 'text-anchor': 'middle') if value
        end
      end
    end

    def draw_medallion
      @s.medallion_arcs.each { |arc| draw_medallion_arc(arc) }
      @s.medallion_cards.each { |card| draw_medallion_card(card) }
      @s.medallion_paths.each { |path| draw_medallion_path(path) }
    end

    def draw_medallion_arc(arc)
      role = arc[:style]
      color = role == :normal ? 'var(--sgr-muted)' : role == :focal ? 'var(--sgr-accent)' : "var(--sgr-concern-#{role})"
      marker = role == :normal ? 'arrow' : role == :focal ? 'arrow-accent' : "arrow-#{role}"
      start, c1, c2, finish = arc.values_at(:start, :control1, :control2, :finish)
      d = "M #{start.join(' ')} C #{c1.join(' ')}, #{c2.join(' ')}, #{finish.join(' ')}"
      add %(<path #{attrs('data-sgr-medallion-promotion': "#{arc[:promotion].from}-#{arc[:promotion].to}",
                          'data-sgr-medallion-style': role, d: d, fill: 'none', stroke: color,
                          'stroke-width': role == :focal ? 1.6 : 1.4,
                          'stroke-dasharray': arc[:dashed] ? '4 3' : nil,
                          'marker-end': "url(##{@id}-#{marker})")}/>)
      text(arc[:label], arc[:label_x], arc[:label_y], class: 'sgr-medallion-promotion',
           fill: color, 'text-anchor': 'middle')
    end

    def draw_medallion_card(card)
      tier = card[:tier]
      x, y, right, bottom = card[:rect]
      role = tier.focal ? :focal : tier.archive ? :archive : tier.concern
      stroke = tier.focal ? 'var(--sgr-accent)' : tier.archive ? 'var(--sgr-muted)' : tier.concern ? "var(--sgr-concern-#{tier.concern})" : 'var(--sgr-ink)'
      fill = tier.focal ? 'var(--sgr-tint)' : tier.archive ? 'var(--sgr-secondary)' : 'var(--sgr-paper)'
      rect(x, y, right - x, bottom - y, rx: 6, fill: fill, stroke: stroke,
           'stroke-width': tier.focal || tier.concern ? 1.4 : 1,
           'stroke-dasharray': tier.archive ? '4 3' : nil,
           'data-sgr-medallion-tier': tier.id, 'data-sgr-medallion-role': role || :normal)
      hx, hy, hr, hb = card[:header_rect]
      rect(hx, hy, hr - hx, hb - hy, rx: 6, fill: stroke, 'fill-opacity': tier.focal ? 0.14 : 0.08,
           'data-sgr-medallion-header': tier.id)
      text(tier.label, x + 12, y + 26, class: "sgr-medallion-title#{tier.focal ? ' sgr-emphasis' : ''}")
      baselines = { bucket: 146, tool: 204, format: 262, writer: 320 }
      card[:fields].each do |field, lines|
        base = baselines.fetch(field)
        text(field.to_s.upcase, x + 12, base, class: 'sgr-medallion-field-label')
        field_color = field == :bucket && tier.focal ? 'var(--sgr-accent)' :
                      field == :bucket && tier.concern ? "var(--sgr-concern-#{tier.concern})" : nil
        tspan_text(lines, x + 12, base + 17, 'sgr-medallion-field-value', 14,
                   'data-sgr-medallion-field': field, style: field_color ? "fill:#{field_color}" : nil)
      end
      text('EXAMPLES', x + 12, y + 300, class: 'sgr-medallion-field-label')
      example_color = tier.focal ? 'var(--sgr-accent)' : tier.concern ? "var(--sgr-concern-#{tier.concern})" : nil
      tspan_text(card[:examples], x + 12, y + 319, 'sgr-medallion-example', 15,
                 'data-sgr-medallion-examples': tier.id, fill: example_color)
    end

    def draw_medallion_path(entry)
      item = entry[:path]
      x, y, right, bottom = entry[:rect]
      color = item.concern ? "var(--sgr-concern-#{item.concern})" : 'var(--sgr-ink)'
      rect(x, y, right - x, bottom - y, rx: 6, fill: 'var(--sgr-paper)', stroke: color,
           'stroke-opacity': item.concern ? 0.55 : 0.2, 'stroke-width': 1,
           'data-sgr-medallion-write-path': item.id)
      tag_width = entry[:tag_width]
      rect(x + 8, y + 6, tag_width, 14, rx: 2, fill: 'none', stroke: color, 'stroke-opacity': 0.55, 'stroke-width': 0.8)
      text(item.tag, x + 8 + tag_width / 2.0, y + 16, class: 'sgr-medallion-path-tag', fill: color, 'text-anchor': 'middle')
      text(item.title, entry[:title_x], y + 29, class: 'sgr-medallion-path-title', fill: color)
      text(item.detail, entry[:title_x], y + 45, class: 'sgr-medallion-path-detail')
    end

    def tspan_text(lines, x, y, class_name, leading, **options)
      attributes = attrs({ x: x, y: y, class: class_name }.merge(options))
      spans = lines.each_with_index.map do |value, index|
        %(<tspan x="#{esc(x)}" dy="#{index.zero? ? 0 : leading}">#{esc(value)}</tspan>)
      end.join
      add "<text #{attributes}>#{spans}</text>"
    end

    def draw_high_level
      @s.banners.each_with_index { |item, index| draw_high_level_banner(item, index) }
      draw_high_level_regions
      draw_high_level_orchestration if @s.orchestration
      @s.footers.each { |item| draw_high_level_crosscut(item) }
      @s.verticals.each_with_index { |item, index| draw_high_level_vertical(item, index) }
      @s.routes.each { |route| draw_high_level_route(route) }
      @s.boxes.each { |box| draw_high_level_box(box) }
      draw_high_level_legend
    end

    def draw_high_level_banner(item, index)
      points = item[:points].map { |point| point.join(',') }.join(' ')
      fill = index.even? ? 'var(--sgr-high-chevron-a)' : 'var(--sgr-high-chevron-b)'
      add %(<polygon data-sgr-high-level-phase="#{esc(item[:phase].id)}" points="#{points}" fill="#{fill}"/> )
      text(item[:label], item[:cx], 22, class: 'sgr-high-phase', 'text-anchor': 'middle')
    end

    def draw_high_level_regions
      sx, sy, sr, sb = @s.source_zone[:rect]
      rect(sx, sy, sr - sx, sb - sy, rx: 6, fill: 'var(--sgr-ink)', 'fill-opacity': 0.02,
           stroke: 'var(--sgr-rule)', 'stroke-width': 0.8, 'stroke-dasharray': '6 3',
           'data-sgr-source-zone': 'true')
      cx, cy, cr, cb = @s.cluster[:rect]
      rect(cx, cy, cr - cx, cb - cy, rx: 8, fill: 'var(--sgr-ink)', 'fill-opacity': 0.02,
           stroke: 'var(--sgr-rule)', 'stroke-width': 1.2, 'data-sgr-cluster': @d.cluster)
      text(@d.cluster, cx + 16, cb - 14, class: 'sgr-high-cluster')
    end

    def draw_high_level_orchestration
      item = @s.orchestration
      x, y, right, bottom = item[:rect]
      rect(x, y, right - x, bottom - y, rx: 4, fill: 'var(--sgr-ink)', 'fill-opacity': 0.05,
           stroke: 'var(--sgr-rule)', 'stroke-width': 0.8,
           'data-sgr-orchestration': item[:owner].id, 'data-sgr-concern': item[:owner].concern)
      detail = item[:owner].detail
      text(item[:owner].label, (x + right) / 2, detail ? y + 19 : y + 27,
           class: 'sgr-high-name', 'text-anchor': 'middle')
      text(detail, (x + right) / 2, y + 34, class: 'sgr-high-detail', 'text-anchor': 'middle') if detail
    end

    def draw_high_level_crosscut(item)
      crosscut = item[:crosscut]
      x, y, right, bottom = item[:rect]
      rect(x, y, right - x, bottom - y, rx: 6, fill: 'var(--sgr-ink)', 'fill-opacity': 0.05,
           stroke: 'var(--sgr-rule)', 'stroke-width': 0.8,
           'data-sgr-crosscut': crosscut.id, 'data-sgr-concern': crosscut.concern)
      text(crosscut.label, (x + right) / 2, crosscut.detail ? y + 17 : y + 25,
           class: 'sgr-high-name', 'text-anchor': 'middle')
      text(crosscut.detail, (x + right) / 2, y + 32, class: 'sgr-high-detail', 'text-anchor': 'middle') if crosscut.detail
    end

    def draw_high_level_vertical(item, index)
      points = item[:points].map { |point| point.join(',') }.join(' ')
      fill = index.even? ? 'var(--sgr-high-chevron-a)' : 'var(--sgr-high-chevron-b)'
      add %(<polygon data-sgr-vertical-concern="#{esc(item[:concern])}" data-sgr-concern-kind="#{item[:kind]}" points="#{points}" fill="#{fill}"/> )
      x, y, right, bottom = item[:rect]
      center_x, center_y = (x + right) / 2, (y + bottom) / 2
      text(item[:label], center_x, center_y, class: 'sgr-high-concern', 'text-anchor': 'middle',
           transform: "rotate(-90 #{center_x} #{center_y})")
    end

    def draw_high_level_route(route)
      stroke, width, dash, marker = case route.style
      when :primary then ['var(--sgr-accent)', 1.2, nil, 'arrow-accent']
      when :trigger then ['var(--sgr-muted)', 1, '4 3', 'arrow-sm']
      else ['var(--sgr-muted)', 1, nil, 'arrow']
      end
      add %(<path data-sgr-connector="true" data-sgr-high-level-connection="#{esc("#{route.edge.from}-#{route.edge.to}")}" data-sgr-high-level-style="#{route.style}" d="#{rounded_path(route.points)}" fill="none" stroke="#{stroke}" stroke-width="#{width}"#{dash ? " stroke-dasharray=\"#{dash}\"" : ''} marker-end="url(##{@id}-#{marker})"/> )
    end

    def draw_high_level_box(box)
      item = box.node
      source = item.is_a?(HighLevelSource)
      focal = !source && item.focal
      fill = focal ? 'var(--sgr-tint)' : 'var(--sgr-paper)'
      stroke = focal ? 'var(--sgr-accent)' : 'var(--sgr-ink)'
      attributes = source ?
        { 'data-sgr-source': item.id, 'data-sgr-source-type': item.source_type } :
        { 'data-sgr-component': item.id, 'data-sgr-focal': item.focal }
      rect(box.x, box.y, box.width, box.height, rx: 6, fill: fill, stroke: stroke,
           'stroke-width': focal ? 1.2 : 1, **attributes)
      badge = source ? "EXT · #{item.source_type.to_s.upcase}" : item.role
      badge_width = Text.grid(Text.width(badge, 8, font: :mono) + badge.length * 0.32 + 12)
      rect(box.x + 8, box.y + 6, badge_width, 14, rx: 2, fill: 'var(--sgr-secondary)',
           stroke: focal ? 'var(--sgr-accent)' : 'var(--sgr-rule)', 'stroke-width': 0.8)
      text(badge, box.x + 8 + badge_width / 2, box.y + 16, class: 'sgr-high-role', 'text-anchor': 'middle')
      name_y = source ? box.y + 42 : box.y + (item.detail ? 48 : 52)
      text(item.label, box.center[0], name_y, class: "sgr-high-name#{focal ? ' sgr-emphasis' : ''}", 'text-anchor': 'middle')
      detail_y = source ? box.y + 57 : box.y + 64
      text(item.detail, box.center[0], detail_y, class: 'sgr-high-detail', 'text-anchor': 'middle') if item.detail
    end

    def draw_high_level_legend
      @s.legend_entries.each do |entry|
        x, y, = entry[:rect]
        style = entry[:kind]
        stroke = style == :primary ? 'var(--sgr-accent)' : 'var(--sgr-muted)'
        marker = style == :primary ? 'arrow-accent' : style == :trigger ? 'arrow-sm' : 'arrow'
        dash = style == :trigger ? ' stroke-dasharray="4 3"' : ''
        add %(<line data-sgr-legend-kind="#{style}" x1="#{x}" y1="#{y + 11}" x2="#{x + 28}" y2="#{y + 11}" stroke="#{stroke}" stroke-width="1"#{dash} marker-end="url(##{@id}-#{marker})"/> )
        text(entry[:label], x + 38, y + 15, class: 'sgr-high-legend')
      end
    end

    def draw_it_state
      @s.zones.each { |zone| draw_it_phase(zone) }
      previous_routes = []
      @s.routes.sort_by { |route| route.edge.dashed ? 1 : 0 }.each do |route|
        draw_it_handoff(route, previous_routes)
        previous_routes << route
      end
      @s.routes.each { |route| draw_it_handoff_label(route) }
      @s.boxes.each { |box| draw_it_system(box) }
      @s.footers.each { |footer| draw_it_crosscut(footer) }
      draw_it_legend
    end

    def draw_it_phase(zone)
      x, y, right, bottom = zone[:rect]
      rect(x, y, right - x, bottom - y, rx: 8, fill: 'var(--sgr-ink)', 'fill-opacity': 0.02,
           stroke: 'var(--sgr-rule)', 'stroke-width': 0.8, 'data-sgr-phase': zone[:id])
      hx, hy, hr, hb = zone[:header_rect]
      rect(hx, hy, hr - hx, hb - hy, fill: 'var(--sgr-paper)', 'data-sgr-phase-header': zone[:id])
      text(zone[:label], hx + 8, hy + 13, class: 'sgr-it-phase')
    end

    def draw_it_handoff(route, previous_routes)
      crossings = previous_routes.flat_map do |previous|
        route.points.each_cons(2).flat_map do |a, b|
          previous.points.each_cons(2).filter_map { |c, d| Layout::Geometry.crossing(a, b, c, d) }
        end
      end.uniq
      effective = @d.effective_handoff_style(route.edge)
      stroke = effective == :neutral ? 'var(--sgr-muted)' : "var(--sgr-#{effective})"
      width = { neutral: 1.0, link: 1.2, accent: 1.4 }.fetch(effective)
      marker = effective == :neutral ? 'arrow' : "arrow-#{effective}"
      add %(<path #{attrs(
        'data-sgr-connector': 'true', 'data-sgr-hops': crossings.size,
        'data-sgr-handoff': "#{route.edge.from}-#{route.edge.to}",
        'data-sgr-handoff-requested-style': route.edge.kind,
        'data-sgr-handoff-style': effective,
        d: rounded_path(route.points, crossings), fill: 'none', stroke: stroke, 'stroke-width': width,
        'stroke-dasharray': route.edge.dashed ? '4 3' : nil,
        'marker-end': "url(##{@id}-#{marker})"
      )}/>)
    end

    def draw_it_handoff_label(route)
      x, y, right, bottom = route.label_box[:rect]
      effective = @d.effective_handoff_style(route.edge)
      color = effective == :neutral ? 'var(--sgr-muted)' : "var(--sgr-#{effective})"
      rect(x, y, right - x, bottom - y, rx: 3, fill: 'var(--sgr-paper)',
           'data-sgr-handoff-label': "#{route.edge.from}-#{route.edge.to}")
      text(route.edge.label, (x + right) / 2, y + 12, class: 'sgr-it-handoff-label',
           fill: color, 'text-anchor': 'middle')
    end

    def draw_it_system(box)
      node = box.node
      fill, stroke, width, dash = case node.kind
      when :pain_point then ['var(--sgr-tint)', 'var(--sgr-accent)', 1.4, nil]
      when :external then ['var(--sgr-paper)', 'var(--sgr-muted)', 1, '4 3']
      else ['var(--sgr-paper)', 'var(--sgr-ink)', 1, nil]
      end
      rect(box.x, box.y, box.width, box.height, rx: 6, fill: fill, stroke: stroke,
           'stroke-width': width, 'stroke-dasharray': dash,
           'data-sgr-system': node.id, 'data-sgr-system-state': node.kind, 'data-sgr-system-phase': node.zone)
      content_height = box.lines.size * 20 + box.details.size * 16 + (box.details.empty? ? 0 : 6)
      cursor = box.y + (box.height - content_height) / 2
      box.lines.each_with_index do |value, index|
        text(value, box.x + 20, cursor + 16 + index * 20, class: 'sgr-it-system-name')
      end
      cursor += box.lines.size * 20 + 6
      box.details.each_with_index do |value, index|
        class_name = node.kind == :pain_point && index.zero? ? 'sgr-it-pain-detail' : 'sgr-it-system-detail'
        text(value, box.x + 20, cursor + 12 + index * 16, class: class_name)
      end
    end

    def draw_it_crosscut(footer)
      item = footer[:crosscut]
      x, y, right, bottom = footer[:rect]
      rect(x, y, right - x, bottom - y, rx: 8, fill: 'var(--sgr-ink)', 'fill-opacity': 0.03,
           stroke: 'var(--sgr-rule)', 'stroke-width': 0.8, 'data-sgr-crosscut': item.id)
      footer[:label_lines].each_with_index do |value, index|
        text(value, x + 20, footer[:label_y] + index * 20, class: 'sgr-it-crosscut-name')
      end
      footer[:detail_lines].each_with_index do |value, index|
        text(value, x + 20, footer[:detail_y] + index * 16, class: 'sgr-it-crosscut-detail')
      end
    end

    def draw_it_legend
      add '<g data-sgr-legend="true">'
      line(@s.legend_rect[0], @s.legend_rect[1], @s.legend_rect[2], @s.legend_rect[1], 'var(--sgr-rule)')
      @s.legend_entries.each do |entry|
        x, y, = entry[:rect]
        add %(<g data-sgr-legend-kind="#{entry[:kind]}">)
        case entry[:kind]
        when :neutral, :link, :accent, :dashed
          color = entry[:kind] == :neutral || entry[:kind] == :dashed ? 'var(--sgr-muted)' : "var(--sgr-#{entry[:kind]})"
          line(x + 4, y + 10, x + 20, y + 10, color, dashed: entry[:kind] == :dashed, dash_pattern: '4 3')
        when :pain_point
          rect(x + 4, y + 4, 16, 12, rx: 3, fill: 'var(--sgr-tint)', stroke: 'var(--sgr-accent)', 'stroke-width': 1)
        when :external
          rect(x + 4, y + 4, 16, 12, rx: 3, fill: 'var(--sgr-paper)', stroke: 'var(--sgr-muted)',
               'stroke-width': 1, 'stroke-dasharray': '4 3')
        end
        text(entry[:label], x + 26, y + 14, class: 'sgr-it-legend-label')
        add '</g>'
      end
      add '</g>'
    end

    def draw_state_machine
      @s.routes.each { |route| draw_state_transition(route) }
      draw_state_markers
      @s.boxes.each { |box| draw_state_box(box) }
      @s.routes.each { |route| draw_state_transition_label(route.label_box) }
    end

    def draw_state_transition(route)
      item = route.transition
      path = "M #{state_point(route.start)} C #{state_point(route.control1)}, #{state_point(route.control2)}, #{state_point(route.finish)}"
      add %(<path #{attrs(
        'data-sgr-state-transition': "#{item.from}-#{item.to}",
        'data-sgr-state-route': route.kind,
        d: path,
        fill: 'none', stroke: 'var(--sgr-muted)', 'stroke-width': 1.2,
        'marker-end': "url(##{@id}-arrow)"
      )}/>)
    end

    def draw_state_markers
      entry = @s.entry
      add %(<line #{attrs(
        'data-sgr-state-entry-line': entry[:state], x1: entry[:dot][0], y1: entry[:dot][1],
        x2: entry[:finish][0], y2: entry[:finish][1], stroke: 'var(--sgr-muted)',
        'stroke-width': 1.2, 'marker-end': "url(##{@id}-arrow)"
      )}/>)
      add %(<circle #{attrs('data-sgr-state-entry': entry[:state], cx: entry[:dot][0], cy: entry[:dot][1], r: 6, fill: 'var(--sgr-ink)')}/>)
      @s.finals.each do |item|
        add %(<line #{attrs(
          'data-sgr-state-final-line': item[:state], x1: item[:start][0], y1: item[:start][1],
          x2: item[:outer][0], y2: item[:outer][1], stroke: 'var(--sgr-muted)', 'stroke-width': 1.2
        )}/>)
        add %(<circle #{attrs('data-sgr-state-final': item[:state], cx: item[:outer][0], cy: item[:outer][1], r: 8, fill: 'var(--sgr-paper)', stroke: 'var(--sgr-ink)', 'stroke-width': 1)}/>)
        add %(<circle #{attrs('data-sgr-state-final-core': item[:state], cx: item[:outer][0], cy: item[:outer][1], r: 5, fill: 'var(--sgr-ink)')}/>)
      end
    end

    def draw_state_box(box)
      state = box.node
      fill = state.emphasis ? 'var(--sgr-tint)' : 'var(--sgr-paper)'
      stroke = state.emphasis ? 'var(--sgr-accent)' : 'var(--sgr-ink)'
      rect(box.x, box.y, box.width, box.height, rx: 8, fill: fill, stroke: stroke, 'stroke-width': 1,
           'data-sgr-state': state.id)
      content_height = box.lines.size * 20 + box.details.size * 16
      y = box.y + (box.height - content_height) / 2 + 16
      box.lines.each_with_index do |value, index|
        text(value, box.center[0], y + index * 20, 'text-anchor': 'middle',
             class: "sgr-name#{state.emphasis ? ' sgr-emphasis' : ''}")
      end
      box.details.each_with_index do |value, index|
        text(value, box.center[0], y + box.lines.size * 20 + index * 16, 'text-anchor': 'middle',
             class: 'sgr-state-detail', 'data-sgr-state-detail': state.id)
      end
    end

    def draw_state_transition_label(label)
      x, y, right, bottom = label[:rect]
      rect(x, y, right - x, bottom - y, rx: 4, fill: 'var(--sgr-paper)', 'fill-opacity': 0.96)
      label[:lines].each_with_index do |value, index|
        text(value, (x + right) / 2, y + 16 + index * 16, class: 'sgr-state-label', 'text-anchor': 'middle')
      end
    end

    def state_point(value) = value.map { |number| number.round(2) }.join(' ')

    def draw_frame(frame)
      x, y, r, b = frame[:rect]
      rect(x, y, r - x, b - y, rx: 4, fill: 'var(--sgr-secondary)', 'fill-opacity': 0.3,
           stroke: 'var(--sgr-rule)', 'stroke-width': 0.8, 'data-sgr-frame': frame[:operator])
      frame[:regions].each do |region|
        line(x, region[:divider], r, region[:divider], 'var(--sgr-rule)', dashed: true) if region[:divider]
      end
    end

    def draw_frame_captions(frame)
      x, y, = frame[:rect]
      rect(x, y, 56, 24, fill: 'var(--sgr-paper)', stroke: 'var(--sgr-rule)', 'stroke-width': 0.8)
      text(frame[:operator].to_s.upcase, x + 28, y + 16, class: 'sgr-frame-operator', 'text-anchor': 'middle')
      frame[:regions].each do |region|
        region[:lines].each_with_index { |value, i| text(value, region[:x], region[:y] + i * 16, class: 'sgr-frame-guard') }
      end
    end

    def draw_activation(bar)
      x, y, r, b = bar[:rect]
      rect(x, y, r - x, b - y, fill: 'var(--sgr-secondary)', stroke: 'var(--sgr-muted)', 'stroke-width': 0.8,
           'data-sgr-activation': bar[:actor], 'data-sgr-depth': bar[:depth])
    end

    def draw_zone(zone)
      x, y, r, b = zone[:rect]
      if @d.type == :deployment
        rect(x, y, r - x, b - y, rx: 8, fill: 'var(--sgr-ink)', 'fill-opacity': 0.02,
             stroke: 'var(--sgr-rule)', 'stroke-width': 1, 'stroke-dasharray': '4 4',
             'data-sgr-deployment-zone': zone[:id])
        hx, hy, hr, hb = zone[:header_rect]
        rect(hx, hy, hr - hx, hb - hy, fill: 'var(--sgr-paper)', 'data-sgr-zone-header': zone[:id])
        zone[:lines].each_with_index do |value, i|
          text(value, hx + 8, hy + 16 + i * 14, class: 'sgr-deployment-zone')
        end
        return
      end
      rect(x, y, r - x, b - y, rx: 8, fill: 'none', stroke: 'var(--sgr-rule)', 'stroke-dasharray': '4 4')
      zone[:lines].each_with_index { |value, i| text(value, x + 16, y + 20 + i * 16, class: 'sgr-zone') }
    end

    def draw_box(box)
      node = box.node
      return draw_dependency_box(box) if @d.type == :dependency
      return draw_deployment_box(box) if @d.type == :deployment
      motion_item(node.id) do
      fill = node.emphasis ? 'var(--sgr-tint)' : node.kind == :store ? 'var(--sgr-secondary)' : 'var(--sgr-paper)'
      stroke = node.emphasis ? 'var(--sgr-accent)' : node.kind == :external ? 'var(--sgr-rule)' : 'var(--sgr-ink)'
      shape = box.shape || :rectangle
      if shape == :merge
        add %(<circle data-sgr-shape="merge" cx="#{box.center[0]}" cy="#{box.center[1]}" r="4" fill="var(--sgr-ink)"/>)
        next
      elsif shape == :diamond
        points = %i[top right bottom left].map { |side| box.boundary(side).join(',') }.join(' ')
        add %(<polygon data-sgr-shape="decision" points="#{points}" fill="#{fill}" stroke="#{stroke}" stroke-width="1"/>)
      else
        rect(box.x, box.y, box.width, box.height, rx: shape == :terminator ? 20 : @d.style_profile.node_radius, fill: fill, stroke: stroke,
             'stroke-width': node.emphasis ? @d.style_profile.emphasis_width : @d.style_profile.border_width,
             'data-sgr-shape': shape == :terminator ? node.kind : 'step',
             'data-sgr-owner-status': node.unavailable ? 'setup-needed' : nil,
             'stroke-dasharray': node.kind == :external || node.unavailable ? '4 4' : nil)
        if node.kind == :decision
          add %(<path d="M #{box.right - 20} #{box.y + 12} l 4 4 l -4 4 l -4 -4 Z" fill="none" stroke="#{stroke}"/>)
        end
      end
      centered = %i[diamond terminator].include?(shape)
      tx = centered ? box.center[0] : box.x + @d.style_profile.node_inset
      anchor = centered ? 'middle' : 'start'
      if @d.type == :org_chart
        sections = [
          [box.lines || [], 20, 16, "sgr-name#{node.emphasis ? ' sgr-emphasis' : ''}"],
          [box.invocations || [], 16, 13, 'sgr-invoke'],
          [box.scopes || [], 16, 13, 'sgr-scope'],
          [box.details || [], 16, 13, 'sgr-detail'],
          [box.statuses || [], 16, 12, 'sgr-owner-status']
        ].reject { |content, _leading, _baseline, _class_name| content.empty? }
        content_height = sections.sum { |content, leading, _baseline, _class_name| content.size * leading } + [sections.size - 1, 0].max * 5
        cursor = box.y + (box.height - content_height) / 2
        sections.each_with_index do |(content, leading, baseline, class_name), section_index|
          cursor += 5 if section_index.positive?
          content.each_with_index { |value, i| text(value, tx, cursor + baseline + i * leading, 'text-anchor': anchor, class: class_name) }
          cursor += content.size * leading
        end
      else
        content_height = box.lines.size * 20 + box.details.size * 16 + (box.details.empty? ? 0 : 8)
        y = box.y + (box.height - content_height) / 2 + 16
        box.lines.each_with_index { |value, i| text(value, tx, y + i * 20, 'text-anchor': anchor, class: "sgr-name#{node.emphasis ? ' sgr-emphasis' : ''}") }
        y += box.lines.size * 20 + 6
        box.details.each_with_index { |value, i| text(value, tx, y + i * 16, 'text-anchor': anchor, class: 'sgr-detail') }
      end
      end
    end

    def draw_deployment_box(box)
      node = box.node
      motion_item(node.id) do
      fill = node.emphasis ? 'var(--sgr-tint)' : 'var(--sgr-paper)'
      stroke = node.emphasis ? 'var(--sgr-accent)' : 'var(--sgr-ink)'
      rect(box.x, box.y, box.width, box.height, rx: 6, fill: fill, stroke: stroke, 'stroke-width': 1,
           'data-sgr-infrastructure': node.id, 'data-sgr-infrastructure-kind': node.kind,
           'data-sgr-infrastructure-zone': node.zone)
      tx, ty, tr, tb = box.type_tag[:rect]
      rect(tx, ty, tr - tx, tb - ty, rx: 2, fill: 'var(--sgr-secondary)', stroke: 'var(--sgr-rule)',
           'stroke-width': 0.8, 'data-sgr-infrastructure-tag': node.kind)
      text(box.type_tag[:text], (tx + tr) / 2, ty + 11, class: 'sgr-infrastructure-tag', 'text-anchor': 'middle')
      if box.replica_badge
        bx, by, br, bb = box.replica_badge[:rect]
        rect(bx, by, br - bx, bb - by, rx: 2, fill: 'var(--sgr-paper)', stroke: 'var(--sgr-rule)',
             'stroke-width': 0.8, 'data-sgr-replicas': node.replicas)
        text(box.replica_badge[:text], (bx + br) / 2, by + 11, class: 'sgr-replicas', 'text-anchor': 'middle')
      end
      text(node.label, box.x + 12, box.y + 43, class: "sgr-name#{node.emphasis ? ' sgr-emphasis' : ''}")
      box.artifacts.each do |chip|
        item = chip[:artifact]
        x, y, right, bottom = chip[:rect]
        rect(x, y, right - x, bottom - y, rx: 4, fill: 'var(--sgr-ink)', 'fill-opacity': 0.05,
             stroke: 'var(--sgr-muted)', 'stroke-width': 0.8, 'data-sgr-artifact': item.name,
             'data-sgr-artifact-version': item.version)
        text(item.name, chip[:name_x], y + 16, class: 'sgr-artifact-name')
        text(item.version, chip[:version_x], y + 16, class: 'sgr-artifact-version', 'text-anchor': 'end')
      end
      end
    end

    def draw_dependency_box(box)
      node = box.node
      motion_item(node.id) do
      treatment = if node.kind == :external
        :external
      elsif @d.edges.none? { |edge| edge.from == node.id }
        :leaf
      else
        :internal
      end
      fill, fill_opacity, stroke, dash = case treatment
      when :external then ['var(--sgr-ink)', 0.03, 'var(--sgr-rule)', '4 4']
      when :leaf then ['var(--sgr-ink)', 0.05, 'var(--sgr-muted)', nil]
      else ['var(--sgr-paper)', 1, 'var(--sgr-ink)', nil]
      end
      rect(box.x, box.y, box.width, box.height, rx: 6, fill: fill, 'fill-opacity': fill_opacity,
           stroke: stroke, 'stroke-width': 1, 'stroke-dasharray': dash,
           'data-sgr-dependency': treatment, 'data-sgr-dependency-id': node.id)
      badge_x = box.right - 42
      rect(badge_x, box.y + 7, 34, 14, rx: 2, fill: 'var(--sgr-paper)', stroke: 'var(--sgr-rule)', 'stroke-width': 0.8)
      text(box.badges.first, badge_x + 17, box.y + 17, class: 'sgr-fan-in', 'text-anchor': 'middle')
      if treatment == :external
        text(node.label, box.x + 12, box.y + 22, class: 'sgr-name')
        text(box.metadata.first, box.x + 12, box.y + 43, class: 'sgr-dependency-meta')
      else
        text(node.label, box.x + 12, box.y + 36, class: 'sgr-name')
      end
      end
    end

    def draw_org_callouts
      top = @s.callouts.map { |item| item[:rect][1] }.min
      add '<g data-sgr-org-rules="true">'
      line(40, top - 20, @s.width - 40, top - 20, 'var(--sgr-rule)')
      @s.callouts.each do |item|
        x, y, right, bottom = item[:rect]
        rule = item[:rule]
        setup_gap = item[:setup_gap]
        kind = setup_gap ? :setup_gap : rule.kind
        rect(x, y, right - x, bottom - y, rx: 6, fill: 'var(--sgr-secondary)', 'fill-opacity': 0.48,
             stroke: kind == :approval || kind == :setup_gap ? 'var(--sgr-accent)' : 'var(--sgr-rule)', 'stroke-width': 1,
             class: "sgr-org-rule#{setup_gap ? ' sgr-org-setup-gap' : ''}", 'data-sgr-rule-kind': kind)
        text(kind.to_s.tr('_', ' ').upcase, x + 20, y + 24, class: 'sgr-rule-kind')
        item[:lines].each_with_index { |value, i| text(value, x + 20, y + 50 + i * 18, class: 'sgr-rule-label') }
        owner_y = y + 58 + item[:lines].size * 18
        prefix = setup_gap ? 'For: ' : rule.kind == :escalation ? 'To: ' : 'By: '
        item[:owner_lines].each_with_index do |value, i|
          text("#{i.zero? ? prefix : ''}#{value}", x + 20, owner_y + i * 16, class: 'sgr-rule-owner')
        end
        invoke_y = owner_y + item[:owner_lines].size * 16 + 4
        item[:invoke_lines].each_with_index { |value, i| text(value, x + 20, invoke_y + i * 16, class: 'sgr-invoke') }
      end
      add '</g>'
    end

    def draw_route(route, previous_routes)
      crossings = previous_routes.flat_map do |previous|
        route.points.each_cons(2).flat_map do |a, b|
          previous.points.each_cons(2).filter_map { |c, d| Layout::Geometry.crossing(a, b, c, d) }
        end
      end.uniq
      cycle = route.edge.respond_to?(:cycle) && route.edge.cycle
      deployment = @d.type == :deployment
      deployment_scope = deployment ? network_scope(route.edge) : nil
      emphasized = deployment && route.edge.emphasis
      open = deployment ? route.edge.dashed : route.edge.kind == :async
      role = if cycle || route.edge.kind == :success || emphasized then 'accent'
             elsif deployment_scope == 'cross-zone' then 'link'
             else nil
             end
      marker = "arrow#{role ? "-#{role}" : ''}#{open ? '-open' : ''}"
      stroke = role ? "var(--sgr-#{role})" : 'var(--sgr-muted)'
      kind_attr = route.edge.kind ? %( data-sgr-message-kind="#{route.edge.kind}") : ''
      cycle_attr = cycle ? ' data-sgr-cycle="true"' : ''
      dash = cycle || (deployment && route.edge.dashed) ? '5 4' : route.edge.dashed ? '4 4' : nil
      network_attrs = if deployment
        %( data-sgr-network="#{esc("#{route.edge.from}-#{route.edge.to}")}" data-sgr-network-scope="#{deployment_scope}" data-sgr-network-async="#{route.edge.dashed}" data-sgr-network-emphasis="#{route.edge.emphasis}")
      else
        ''
      end
      stroke_width = emphasized ? 1.6 : 1.2
      motion_route_item(route.edge.from, route.edge.to) do
        add %(<path data-sgr-connector="true" data-sgr-hops="#{crossings.size}"#{kind_attr}#{cycle_attr}#{network_attrs} d="#{rounded_path(route.points, crossings)}" fill="none" stroke="#{stroke}" stroke-width="#{stroke_width}"#{dash ? " stroke-dasharray=\"#{dash}\"" : ''} marker-end="url(##{@id}-#{marker})"/> )
      end
    end

    def motion_item(target)
      return yield unless @motion

      target = Motion::Target.node(target) unless target.is_a?(Motion::Target)
      step = @motion.step_for(target.key)
      return yield unless step

      normalized = target.key
      @motion_matches[normalized] = true
      return if @motion_static && @motion.replaced_at(normalized)
      return yield if @motion_static

      attributes = [
        'data-motion-item="true"',
        %(data-motion-key="#{esc(normalized)}"),
        %(data-step="#{step.number}"),
        %(aria-label="#{esc("Step #{step.number}: #{step.label}")}")
      ]
      until_step = @motion.replaced_at(normalized)
      attributes << %(data-motion-until="#{until_step}") if until_step
      attributes << %(data-motion-replaces="#{esc(step.replaces.join(' '))}") unless step.replaces.empty?
      add "<g #{attributes.join(' ')}>"
      yield
      add '</g>'
    end

    def motion_route_item(from, to, &block)
      return yield unless @motion
      motion_item(Motion::Target.route(from, to), &block)
    end

    def network_scope(edge)
      from = @d.nodes.find { |node| node.id == edge.from }
      to = @d.nodes.find { |node| node.id == edge.to }
      from.zone == to.zone ? 'internal' : 'cross-zone'
    end

    def rounded_path(points, crossings = [])
      remaining = crossings.dup
      result = "M #{points[0].join(' ')}"
      current = points.first
      points.each_cons(3) do |a, b, c|
        first = [(a[0] - b[0]).abs + (a[1] - b[1]).abs, (c[0] - b[0]).abs + (c[1] - b[1]).abs].min
        r = [8, first / 2.0].min
        before = [b[0] + (a[0] <=> b[0]) * r, b[1] + (a[1] <=> b[1]) * r]
        after = [b[0] + (c[0] <=> b[0]) * r, b[1] + (c[1] <=> b[1]) * r]
        result += straight_path(current, before, remaining)
        result += " Q #{b.join(' ')} #{after.join(' ')}"
        current = after
      end
      result += straight_path(current, points.last, remaining)
      unless remaining.empty?
        raise LayoutError, 'Connections cross inside a rounded bend. Split the graph to leave room for a crossing hop.'
      end
      result
    end

    def straight_path(a, b, crossings)
      horizontal = a[1] == b[1]
      axis = horizontal ? 0 : 1
      direction = b[axis] <=> a[axis]
      hits = crossings.select do |point|
        point[1 - axis] == a[1 - axis] && point[axis] > [a[axis], b[axis]].min && point[axis] < [a[axis], b[axis]].max
      end.sort_by { |point| (point[axis] - a[axis]).abs }
      current = a
      result = ''
      hits.each do |point|
        if (point[axis] - current[axis]).abs < 8 || (b[axis] - point[axis]).abs < 8
          raise LayoutError, 'Connections cross too close to a bend. Split the graph to leave room for a crossing hop.'
        end
        before, after = point.dup, point.dup
        before[axis] -= direction * 8
        after[axis] += direction * 8
        result += " L #{before.join(' ')} A 8 8 0 0 1 #{after.join(' ')}"
        current = after
        crossings.delete(point)
      end
      result + " L #{b.join(' ')}"
    end

    def draw_label(label)
      x, y, r, b = label[:rect]
      rect(x, y, r - x, b - y, rx: 4, fill: 'var(--sgr-paper)')
      class_name = label[:cycle] ? 'sgr-cycle-label' : 'sgr-label'
      label[:lines].each_with_index do |value, i|
        text(value, (x + r) / 2, y + 16 + i * 16, class: label[:network] ? 'sgr-network-label' : class_name,
             'text-anchor': 'middle', 'data-sgr-cycle': label[:cycle] ? 'true' : nil,
             'data-sgr-network-label': label[:network] ? value : nil)
      end
    end

    def draw_timeline
      return draw_ordered_timeline if @s.axis&.dig(:mode) == :ordered
      draw_date_timeline
    end

    def draw_ordered_timeline
      line(176, @s.events.first[:y] + 10, 176, @s.events.last[:y] + 10, 'var(--sgr-rule)')
      @s.events.each do |item|
        event, y = item.values_at(:event, :y)
        add %(<circle cx="176" cy="#{y + 10}" r="#{event.emphasis ? @d.style_profile.emphasis_marker_radius : @d.style_profile.event_marker_radius}" fill="#{event.emphasis ? 'var(--sgr-accent)' : 'var(--sgr-muted)'}"/>)
        item[:date_lines].each_with_index { |value, i| text(value, 148, y + 14 + i * 16, class: 'sgr-date', 'text-anchor': 'end') }
        item[:lines].each_with_index { |value, i| text(value, 208, y + 16 + i * 24, class: "sgr-event-title#{event.emphasis ? ' sgr-emphasis' : ''}") }
        item[:details].each_with_index { |value, i| text(value, 208, y + item[:lines].size * 24 + 20 + i * 20, class: 'sgr-event-detail') }
      end
      text('Ordered milestones — spacing does not measure time', 40, @s.height - 8, class: 'sgr-date')
    end

    def draw_date_timeline
      axis = @s.axis
      line(axis[:x1], axis[:y], axis[:x2], axis[:y], 'var(--sgr-rule)')
      axis[:ticks].each do |tick|
        line(tick[:x], axis[:y] - 8, tick[:x], axis[:y] + 8, 'var(--sgr-rule)')
        text(tick[:label], tick[:x], axis[:y] + 28, class: 'sgr-date', 'text-anchor': 'middle')
      end
      previous = []
      axis[:callouts].each do |group|
        points = group[:leader]
        crossings = previous.flat_map { |other| points.each_cons(2).flat_map { |a, b| other.each_cons(2).filter_map { |c, d| Layout::Geometry.crossing(a, b, c, d) } } }.uniq
        add %(<path d="#{rounded_path(points, crossings)}" fill="none" stroke="var(--sgr-rule)" stroke-width="1"/>)
        previous << points
        add %(<circle #{attrs('data-sgr-date': group[:date], 'data-sgr-event-count': group[:entries].size, cx: group[:x], cy: axis[:y], r: group[:emphasis] ? @d.style_profile.emphasis_marker_radius : @d.style_profile.event_marker_radius, fill: group[:emphasis] ? 'var(--sgr-accent)' : 'var(--sgr-muted)')}/>)
        x, y, = group[:rect]
        text(group[:date], x, y + 12, class: 'sgr-date')
        group[:entries].each do |entry|
          top = y + entry[:offset]
          entry[:lines].each_with_index { |value, i| text(value, x, top + 18 + i * 24, class: "sgr-event-title#{entry[:event].emphasis ? ' sgr-emphasis' : ''}") }
          detail_y = top + entry[:lines].size * 24 + 4
          entry[:details].each_with_index { |value, i| text(value, x, detail_y + 14 + i * 20, class: 'sgr-event-detail') }
        end
      end
      text(axis[:caption], 40, @s.height - 16, class: 'sgr-date')
    end

    def esc(value) = CGI.escapeHTML(value.to_s)
    def add(value) = @out << value
    def attrs(values) = values.reject { |_, v| v.nil? }.map { |k, v| %(#{k}="#{esc(v)}") }.join(' ')
    def rect(x, y, width, height, **options) = add(%(<rect #{attrs({ x: x, y: y, width: width, height: height }.merge(options))}/>))
    def text(value, x, y, **options) = add(%(<text #{attrs({ x: x, y: y }.merge(options))}>#{esc(value)}</text>))
    def line(x1, y1, x2, y2, stroke, dashed: false, dash_pattern: '4 4')
      add %(<line #{attrs(x1: x1, y1: y1, x2: x2, y2: y2, stroke: stroke, 'stroke-width': 1, 'stroke-dasharray': dashed ? dash_pattern : nil)}/>)
    end
  end
end
