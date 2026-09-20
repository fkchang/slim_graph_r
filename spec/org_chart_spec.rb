require 'spec_helper'
require 'slim_graph_r/document'

RSpec.describe 'Org chart ownership' do
  def ownership_chart(**options)
    SlimGraphR.diagram(:org_chart, title: 'Operational ownership', **options) do
      owner :lead, 'Studio lead', invoke: '@lead', scope: 'Direction and release approval', emphasis: true, detail: 'Primary contact'
      owner :triage, 'Triage <desk>', invoke: '#help & route', scope: 'Routing, escalation, and 日本語 support'
      owner :missing, 'Future owner', scope: 'Coverage gap', unavailable: true
      edge :lead, :triage
      edge :triage, :missing
      escalation 'Unowned <work> arriving after staffed hours needs careful routing', to: :triage
      approval 'Production & release', by: :lead
    end
  end

  it 'keeps ownership fields semantically distinct and renders unavailable owners and rules safely' do
    graph = ownership_chart
    triage = graph.nodes[1]
    expect([triage.label, triage.invoke, triage.scope, triage.detail, triage.unavailable]).to eq(
      ['Triage <desk>', '#help & route', 'Routing, escalation, and 日本語 support', nil, false]
    )
    expect(graph.rules.map { |rule| [rule.kind, rule.label, rule.owner] }).to eq([
      [:escalation, 'Unowned <work> arriving after staffed hours needs careful routing', 'triage'],
      [:approval, 'Production & release', 'lead']
    ])

    svg = graph.to_svg(id: 'ownership')
    expect { REXML::Document.new(svg) }.not_to raise_error
    expect(svg).to include('class="sgr-invoke"', 'class="sgr-scope"', 'SETUP NEEDED', 'stroke-dasharray="4 4"')
    expect(svg).to include('Unowned &lt;work&gt;', 'Production &amp; release', 'Triage &lt;desk&gt;')
    expect(svg).not_to include('<work>', '<desk>')
    description = REXML::XPath.first(REXML::Document.new(svg), '//*[local-name()="desc"]').text
    expect(description).to include('Invocation: #help & route', 'Scope: Coverage gap', 'Setup needed', 'Escalation: Unowned <work> arriving after staffed hours needs careful routing to Triage <desk>', 'Approval: Production & release by Studio lead')
  end

  it 'appends complete ownership semantics to an author description' do
    graph = SlimGraphR.diagram(:org_chart, description: 'A fictional operating map.') do
      owner :lead, 'Lead', invoke: '@lead', scope: 'Direction', unavailable: true
      approval 'Release', by: :lead
    end
    description = REXML::XPath.first(REXML::Document.new(graph.to_svg), '//*[local-name()="desc"]').text
    expect(description).to include('A fictional operating map.', 'Invocation: @lead', 'Scope: Direction', 'Setup needed', 'Approval: Release by Lead')
  end

  it 'describes available owners without a false status' do
    graph = SlimGraphR.diagram(:org_chart) do
      owner :lead, 'Lead', invoke: '@lead', scope: 'Direction'
    end
    description = REXML::XPath.first(REXML::Document.new(graph.to_svg), '//*[local-name()="desc"]').text
    expect(description).to include('Lead. Invocation: @lead. Scope: Direction')
    expect(description).not_to include('false', 'Setup needed')
  end

  it 'preserves generic org-chart nodes, edges, detail and forests' do
    graph = SlimGraphR.diagram(:org_chart) do
      node :studio, 'Studio', detail: 'Existing detail', emphasis: true
      node :design
      node :independent
      edge :studio, :design
    end
    expect(graph.nodes.first.detail).to eq('Existing detail')
    expect(graph.nodes.map(&:invoke)).to all(be_nil)
    expect(graph.layout.boxes.map { |box| box.node.id }).to contain_exactly('studio', 'design', 'independent')
  end

  it 'rejects org-specific DSL on other diagram types' do
    expect { SlimGraphR.diagram { owner :lead, 'Lead', scope: 'Everything' } }.to raise_error(SlimGraphR::Error, /only in an org chart/)
    expect { SlimGraphR.diagram { node :lead, scope: 'Everything' } }.to raise_error(SlimGraphR::Error, /only in an org chart/)
    expect { SlimGraphR.diagram { node :lead; escalation 'Missing work', to: :lead } }.to raise_error(SlimGraphR::Error, /only in an org chart/)
    expect { SlimGraphR.diagram { node :lead; approval 'Release', by: :lead } }.to raise_error(SlimGraphR::Error, /only in an org chart/)
    expect { SlimGraphR.diagram(:org_chart) { owner :lead, ' ', scope: 'Direction' } }.to raise_error(SlimGraphR::Error, /name must not be blank/)
    expect { SlimGraphR.diagram(:org_chart) { owner :lead, 'Lead', invoke: ' ' } }.to raise_error(SlimGraphR::Error, /must not be blank/)
  end

  it 'enforces org topology and reference budgets with actionable errors' do
    expect { SlimGraphR.diagram(:org_chart) { 13.times { |i| node "n#{i}" } } }.to raise_error(SlimGraphR::Error, /twelve visible nodes/)
    expect do
      SlimGraphR.diagram(:org_chart) do
        node :lead
        6.times { |i| node "n#{i}"; edge :lead, "n#{i}" }
      end
    end.to raise_error(SlimGraphR::Error, /five direct reports.*lead/)
    expect do
      SlimGraphR.diagram(:org_chart) do
        5.times { |i| node "n#{i}" }
        flow :n0, :n1, :n2, :n3, :n4
      end
    end.to raise_error(SlimGraphR::Error, /four tiers/)
    expect { SlimGraphR.diagram(:org_chart) { node :a, emphasis: true; node :b, emphasis: true } }.to raise_error(SlimGraphR::Error, /one emphasized/)
    expect { SlimGraphR.diagram(:org_chart) { node :a; node :b; flow :a, :b, :a } }.to raise_error(SlimGraphR::Error, /cycle/)
    expect { SlimGraphR.diagram(:org_chart) { node :a; node :b; node :c; edge :a, :c; edge :b, :c } }.to raise_error(SlimGraphR::Error, /one parent/)
    expect { SlimGraphR.diagram(:org_chart) { node :a; escalation 'Lost', to: :missing } }.to raise_error(SlimGraphR::Error, /Unknown escalation owner: missing/)
    expect do
      SlimGraphR.diagram(:org_chart) do
        node :a
        escalation 'One', to: :a
        approval 'Two', by: :a
        escalation 'Three', to: :a
      end
    end.to raise_error(SlimGraphR::Error, /two rule callouts/)
  end

  it 'loads strict JSON with the same meaning and SVG as Ruby' do
    root = File.expand_path('../examples/standalone', __dir__)
    ruby = eval(File.read(File.join(root, 'org_ownership.rb')), binding, File.join(root, 'org_ownership.rb'))
    json = SlimGraphR::Document.from_json(File.read(File.join(root, 'org_ownership.json')))
    expect(json.to_svg(id: 'org-parity')).to eq(ruby.to_svg(id: 'org-parity'))

    bad = { type: 'architecture', nodes: [{ id: 'a', scope: 'Org only' }] }
    expect { SlimGraphR::Document.from_json(JSON.generate(bad)) }.to raise_error(SlimGraphR::Error, /only valid for org_chart/)
    expect { SlimGraphR::Document.from_json(JSON.generate(type: 'architecture', nodes: [{ id: 'a' }], escalations: [{ label: 'Lost', to: 'a' }])) }.to raise_error(SlimGraphR::Error, /only valid for org_chart/)
    expect { SlimGraphR::Document.from_json(JSON.generate(type: 'architecture', nodes: [{ id: 'a' }], approvals: [])) }.to raise_error(SlimGraphR::Error, /only valid for org_chart/)
    expect { SlimGraphR::Document.from_json(JSON.generate(type: 'org_chart', nodes: [{ id: 'a', unavailable: 'yes' }])) }.to raise_error(SlimGraphR::Error, /true or false/)
    expect { SlimGraphR::Document.from_json(JSON.generate(type: 'org_chart', nodes: [{ id: 'a' }], approvals: [{ label: 'Release', by: 'a', html: '<b>x</b>' }])) }.to raise_error(SlimGraphR::Error, /Unknown approvals fields: html/)
  end

  it 'contains separately measured Unicode ownership and wrapped rules in every style and theme' do
    SlimGraphR::Style.names.product(%i[light dark auto]).each do |style, theme|
      scene = ownership_chart(style: style, theme: theme).layout
      expect(scene.callouts.size).to eq(2)
      expect(scene.callouts.first[:lines].size).to be > 1
      scene.boxes.each do |box|
        expect(box.x).to be >= 0
        expect(box.y).to be >= 0
        expect(box.right).to be <= scene.width
        expect(box.bottom).to be <= scene.height
      end
      scene.callouts.each do |callout|
        x, y, right, bottom = callout[:rect]
        expect(x).to be >= 0
        expect(y).to be > scene.boxes.map(&:bottom).max
        expect(right).to be <= scene.width
        expect(bottom).to be <= scene.height
      end
      expect(scene.callouts.map { |item| item[:rect] }.combination(2).none? { |a, b| SlimGraphR::Layout::Geometry.overlaps?(a, b) }).to be(true)
      footer_top = scene.callouts.map { |item| item[:rect][1] }.min
      expect(scene.routes.flat_map(&:points).map(&:last).max).to be < footer_top - 20
    end
  end

  it 'leaves non-org geometry and typography unchanged when ownership fields are absent' do
    graph = SlimGraphR.diagram(:architecture) { node :a, 'Name', detail: 'Detail' }
    box = graph.layout.boxes.first
    expect([box.width, box.height, box.lines, box.details]).to eq([224, 88, ['Name'], ['Detail']])
    expect(graph.to_svg(id: 'plain')).not_to match(/<(?:text|rect)[^>]+class="sgr-(?:invoke|scope|org-rule)"/)
  end

  it 'keeps long owner names and both rule prefixes within the footer cards' do
    SlimGraphR::Style.names.product(%i[light dark auto]).each do |style, theme|
      graph = SlimGraphR.diagram(:org_chart, style: style, theme: theme) do
        owner :lead, 'M' * 24
        escalation 'Unowned work', to: :lead
        approval 'Release', by: :lead
      end
      scene = graph.layout
      document = REXML::Document.new(graph.to_svg)
      owner_texts = REXML::XPath.match(document, '//*[local-name()="text" and @class="sgr-rule-owner"]')
      scene.callouts.each do |callout|
        texts = owner_texts.shift(callout[:owner_lines].size)
        prefix = callout[:rule].kind == :escalation ? 'To: ' : 'By: '
        expect(texts.first.text).to start_with(prefix)
        expect(texts.map(&:text).join.delete_prefix(prefix)).to eq('M' * 24)
        x, y, right, bottom = callout[:rect]
        texts.each do |element|
          expect(element.attributes['x'].to_f).to be >= x + 20
          expect(element.attributes['x'].to_f + SlimGraphR::Text.width(element.text, 12)).to be <= right - 20
          expect(element.attributes['y'].to_f).to be_between(y + 12, bottom - 12)
        end
      end
      expect(owner_texts).to be_empty
    end
  end

  it 'uses explicit setup-gap footer callouts without deriving them from unavailable owners' do
    graph = SlimGraphR.diagram(:org_chart) do
      owner :lead, 'Studio lead', invoke: '@lead', unavailable: true
      owner :specialist, 'Specialist'
      edge :lead, :specialist
      setup_gap 'Slack bot invitation is still missing', for: :specialist
    end
    expect(graph.setup_gaps.map { |gap| [gap.label, gap.owner] }).to eq([['Slack bot invitation is still missing', 'specialist']])
    scene = graph.layout
    expect(scene.callouts.first[:setup_gap]).to be_a(SlimGraphR::OrgSetupGap)
    expect(graph.to_svg(id: 'setup-gap')).to include('SETUP GAP', 'For: Specialist', 'data-sgr-rule-kind="setup_gap"')
    parsed = SlimGraphR::Document.from_json(JSON.generate(
      type: 'org_chart', nodes: [{ id: 'lead', label: 'Studio lead' }], setup_gaps: [{ label: 'Name a release gate', for: 'lead' }]
    ))
    expect(parsed.setup_gaps.first.label).to eq('Name a release gate')
    expect { SlimGraphR.diagram(:org_chart) { owner :lead, 'Lead'; setup_gap 'Missing', for: :unknown } }.to raise_error(SlimGraphR::Error, /Unknown setup-gap owner/)
  end
end
