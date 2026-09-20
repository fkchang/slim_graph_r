# frozen_string_literal: true
require 'spec_helper'
require 'slim_graph_r/document'

RSpec.describe 'bounded nested-containment diagrams' do
  def reference_nested
    SlimGraphR.diagram(:nested, title: 'Instruction cascade') do
      scope :organization, 'Organization' do
        scope :repository, 'Repository' do
          scope :workspace, 'Workspace' do
            scope :task, 'Task'
          end
        end
      end
    end
  end

  let(:json_data) do
    {
      type: 'nested', title: 'Instruction cascade',
      scope: { id: 'organization', label: 'Organization', scope: {
        id: 'repository', label: 'Repository', scope: {
          id: 'workspace', label: 'Workspace', scope: { id: 'task', label: 'Task' }
        }
      } }
    }
  end

  it 'builds one frozen containment chain and keeps strict recursive JSON equivalent' do
    graph = reference_nested
    expect(graph.containment_scopes.map { |item| [item.id, item.parent_id, item.depth] }).to eq([
      ['organization', nil, 1], ['repository', 'organization', 2],
      ['workspace', 'repository', 3], ['task', 'workspace', 4]
    ])
    expect(graph.containment_scopes).to be_frozen
    expect(graph.containment_scopes).to all(be_frozen)
    parsed = SlimGraphR::Document.from_json(JSON.generate(json_data))
    expect(parsed.to_svg(id: 'nested-parity')).to eq(graph.to_svg(id: 'nested-parity'))
  end

  it 'keeps the packaged Ruby and JSON examples equivalent' do
    root = File.expand_path('../examples/standalone', __dir__)
    ruby = eval(File.read(File.join(root, 'nested.rb'), encoding: 'UTF-8'), binding, File.join(root, 'nested.rb'))
    json = SlimGraphR::Document.from_json(File.read(File.join(root, 'nested.json'), encoding: 'UTF-8'))
    expect(json.to_svg(id: 'nested-example')).to eq(ruby.to_svg(id: 'nested-example'))
  end

  it 'requires three to five unique levels in a single nonbranching chain' do
    expect do
      SlimGraphR.diagram(:nested) { scope(:one) { scope :two } }
    end.to raise_error(SlimGraphR::Error, /three to five/i)
    expect do
      SlimGraphR.diagram(:nested) do
        scope(:one) { scope(:two) { scope(:three) { scope(:four) { scope(:five) { scope :six } } } } }
      end
    end.to raise_error(SlimGraphR::Error, /five levels/i)
    expect do
      SlimGraphR.diagram(:nested) { scope(:one) { scope :two; scope :three } }
    end.to raise_error(SlimGraphR::Error, /one inner scope/i)
    expect do
      SlimGraphR.diagram(:nested) { scope(:same) { scope(:same) { scope :three } } }
    end.to raise_error(SlimGraphR::Error, /IDs must be unique/i)
    expect do
      SlimGraphR.diagram(:nested) do
        scope(:outer) do
          scope(:first) { scope :inner }
          scope :sibling
        end
      end
    end.to raise_error(SlimGraphR::Error, /one inner scope/i)
    expect { SlimGraphR.diagram(:nested) { scope(:a) { scope(:b) { scope :c } } } }.not_to raise_error
    expect do
      SlimGraphR.diagram(:nested) { scope(:a) { scope(:b) { scope(:c) { scope(:d) { scope :e } } } } }
    end.not_to raise_error
  end

  it 'rejects explicit nulls, cross-type fields, arrays and unknown recursive fields' do
    invalid = [
      json_data.merge(scope: nil),
      json_data.merge(scope: json_data[:scope].merge(label: nil)),
      json_data.merge(scope: json_data[:scope].merge(scope: [])),
      json_data.merge(scope: json_data[:scope].merge(html: '<b>x</b>')),
      json_data.merge(layers: [])
    ]
    invalid.each { |data| expect { SlimGraphR::Document.from_json(JSON.generate(data)) }.to raise_error(SlimGraphR::Error) }
    duplicate = Marshal.load(Marshal.dump(json_data))
    duplicate[:scope][:scope][:scope][:id] = 'organization'
    expect { SlimGraphR::Document.from_json(JSON.generate(duplicate)) }.to raise_error(SlimGraphR::Error, /IDs must be unique/i)
    parsed = SlimGraphR::Document.from_json(JSON.generate(json_data))
    expect(parsed.containment_scopes.flat_map { |item| [item.id, item.label] }).to all(be_frozen)
  end

  it 'renders regular containment geometry with only the innermost scope accented' do
    svg = reference_nested.to_svg(id: 'nested-geometry')
    expect(svg).to include('data-sgr-nested="true"', 'data-sgr-scope="organization"', 'data-sgr-scope="task"')
    expect(svg.scan(/data-sgr-inset-x="28"/).size).to eq(4)
    expect(svg.scan(/data-sgr-inset-y="34"/).size).to eq(4)
    expect(svg.scan(/data-sgr-scope-focal="true"/).size).to eq(1)
    expect(svg).to include('data-sgr-scope-label-mask="task"')
    scene = reference_nested.layout
    scene.nested_scopes.each_cons(2) do |outer, inner|
      ox, oy, oright, obottom = outer[:rect]
      ix, iy, iright, ibottom = inner[:rect]
      expect([ix - ox, iy - oy, oright - iright, obottom - ibottom]).to eq([28, 34, 28, 34])
    end
    expect(scene.nested_scopes.map { |item| item[:label] }).to eq(%w[ORGANIZATION REPOSITORY WORKSPACE TASK])
    expect do
      SlimGraphR.diagram(:nested) { scope(:a) { scope(:b) { scope :c, 'W' * 120 } } }.to_svg
    end.to raise_error(SlimGraphR::LayoutError, /shorten/i)
  end

  it 'supports all styles and themes and honors an authored description exactly' do
    %i[editorial ruby blueprint mono].product(%i[light dark auto]).each do |style, theme|
      expect(reference_nested.with(style: style, theme: theme).to_svg).to include(%(data-sgr-style="#{style}"), %(data-sgr-theme="#{theme}"))
    end
    custom = SlimGraphR.diagram(:nested, description: 'Exact scope summary') do
      scope(:one) { scope(:two) { scope :three } }
    end
    expect(custom.to_svg).to include('>Exact scope summary</desc>')
    expect(custom.to_svg).not_to include('Containment chain.')
    generated = reference_nested.to_svg
    expect(generated).to include('Containment chain.', 'Organization contains Repository contains Workspace contains Task', 'Innermost: Task')
  end
end
