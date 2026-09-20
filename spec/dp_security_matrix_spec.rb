# frozen_string_literal: true
require 'spec_helper'
require 'slim_graph_r/document'
require 'json'
require 'rexml/document'

RSpec.describe 'DP security matrix diagrams' do
  def build(description: nil)
    SlimGraphR.diagram(:dp_security_matrix, title: 'Recorded access · 権限表', description: description) do
      role :admins, 'Data administrators', code: 'DL-DataAdmins'
      role :engineers, 'Data engineers'
      component :raw, 'Raw store', hint: 'S3'
      component :catalog, 'Aggregate catalog', hint: 'SQL'
      permission :raw, :admins, level: :admin
      permission :raw, :engineers, level: :write
      permission :catalog, :admins, level: :unknown
      permission :catalog, :engineers, 'Select only', level: :read,
                 note: 'published aggregate', focal: true
    end
  end

  it 'owns immutable explicit role, component, and permission records' do
    diagram = build
    expect(diagram.security_roles.map(&:id)).to eq(%w[admins engineers])
    expect(diagram.security_components.map(&:id)).to eq(%w[raw catalog])
    expect(diagram.security_permissions.map { |cell| [cell.component, cell.role, cell.level, cell.label] }).to eq([
      ['raw', 'admins', :admin, 'Admin'], ['raw', 'engineers', :write, 'Read/write'],
      ['catalog', 'admins', :unknown, 'Unknown'], ['catalog', 'engineers', :read, 'Select only']
    ])
    expect(diagram.security_roles.first.code).to eq('DL-DataAdmins')
    expect(diagram.security_roles.last.code).to be_nil
    expect(diagram.security_components.first.hint).to eq('S3')
    expect(diagram.security_permissions).to be_frozen
    expect(diagram.security_permissions.all?(&:frozen?)).to be(true)
  end

  it 'copies caller strings and remains usable from nested author context' do
    role_label = +'Operators'
    component_label = +'Warehouse'
    permission_label = +'Read only'
    author = Object.new
    diagram = author.instance_exec do
      SlimGraphR.diagram(:dp_security_matrix) do
        role :operators, role_label
        role :auditors, 'Auditors'
        component :warehouse, component_label
        component :reports, 'Reports'
        permission :warehouse, :operators, permission_label, level: :read
        permission :warehouse, :auditors, level: :unknown
        permission :reports, :operators, level: :write
        permission :reports, :auditors, level: :deny
      end
    end
    role_label.replace('changed'); component_label.replace('changed'); permission_label.replace('changed')
    expect(diagram.security_roles.first.label).to eq('Operators')
    expect(diagram.security_components.first.label).to eq('Warehouse')
    expect(diagram.security_permissions.first.label).to eq('Read only')
  end

  it 'enforces labels, unique IDs, bounded cardinality, one focal cell, and optional metadata omission' do
    expect { SlimGraphR.diagram(:dp_security_matrix) { role :a } }.to raise_error(SlimGraphR::Error, /role label.*required/i)
    expect { SlimGraphR.diagram(:dp_security_matrix) { component :x, nil } }.to raise_error(SlimGraphR::Error, /component label/i)
    expect do
      SlimGraphR.diagram(:dp_security_matrix) { role :a, 'A'; role :a, 'Again'; component :x, 'X'; component :y, 'Y' }
    end.to raise_error(SlimGraphR::Error, /role IDs must be unique/i)
    expect do
      SlimGraphR.diagram(:dp_security_matrix) do
        role :a, 'A'; role :b, 'B'; component :x, 'X'; component :y, 'Y'
        permission :x, :a, level: :read, focal: true
        permission :x, :b, level: :read, focal: true
        permission :y, :a, level: :read
        permission :y, :b, level: :read
      end
    end.to raise_error(SlimGraphR::Error, /at most one focal/i)
    expect(build.security_roles.last.code).to be_nil
  end

  it 'requires an explicit complete grid and distinguishes unknown, denial, and omission' do
    expect do
      SlimGraphR.diagram(:dp_security_matrix) do
        role :a, 'A'; role :b, 'B'; component :x, 'X'; component :y, 'Y'
        permission :x, :a, level: :deny
        permission :x, :b, level: :unknown
        permission :y, :a, level: :read
      end
    end.to raise_error(SlimGraphR::Error, /missing explicit permission.*y.*b/i)

    expect(build.security_permissions.map(&:level)).to include(:unknown)
  end

  it 'rejects duplicate coordinates, references, enums, booleans, notes outside focal cells, and extra options' do
    expect do
      SlimGraphR.diagram(:dp_security_matrix) do
        role :a, 'A'; role :b, 'B'; component :x, 'X'; component :y, 'Y'
        permission :x, :a, level: :read
        permission :x, :a, level: :deny
      end
    end.to raise_error(SlimGraphR::Error, /duplicate permission/i)
    expect do
      SlimGraphR.diagram(:dp_security_matrix, direction: :right) {}
    end.to raise_error(SlimGraphR::Error, /fixed.*down/i)
    expect do
      SlimGraphR.diagram(:dp_security_matrix) { role :a, 'A', color: '#fff' }
    end.to raise_error(SlimGraphR::Error, /unknown.*role.*color/i)
    expect do
      SlimGraphR.diagram(:dp_security_matrix) { permission :x, :y, level: :full }
    end.to raise_error(SlimGraphR::Error, /level.*admin.*write.*read.*deny.*unknown/i)
    expect do
      SlimGraphR.diagram(:dp_security_matrix) { permission :x, :y, level: :read, focal: 'true' }
    end.to raise_error(SlimGraphR::Error, /focal must be true or false/i)
    expect do
      SlimGraphR.diagram(:dp_security_matrix) { permission :x, :y, level: :read, note: 'why' }
    end.to raise_error(SlimGraphR::Error, /note.*focal/i)
  end

  it 'rejects generic records and connector-like DSL' do
    expect { SlimGraphR.diagram(:dp_security_matrix) { node :x } }.to raise_error(SlimGraphR::Error, /dedicated.*matrix/i)
    expect { SlimGraphR.diagram(:dp_security_matrix) { edge :x, :y } }.to raise_error(SlimGraphR::Error, /no connectors/i)
    expect { SlimGraphR.diagram(:dp_security_matrix) { connect :x, :y } }.to raise_error(SlimGraphR::Error, /no connectors/i)
  end

  it 'round trips strict JSON to the same model, description, and stable SVG' do
    json = File.read(File.expand_path('../examples/standalone/dp_security_matrix.json', __dir__), encoding: 'UTF-8')
    parsed = SlimGraphR::Document.from_json(json)
    ruby = eval(File.read(File.expand_path('../examples/standalone/dp_security_matrix.rb', __dir__), encoding: 'UTF-8'))
    expect(parsed.security_roles).to eq(ruby.security_roles)
    expect(parsed.security_components).to eq(ruby.security_components)
    expect(parsed.security_permissions).to eq(ruby.security_permissions)
    expect(parsed.to_svg(id: 'stable')).to eq(ruby.to_svg(id: 'stable'))
  end

  it 'strictly rejects unknown, null, cross-type, malformed, duplicate, and partial JSON' do
    path = File.expand_path('../examples/standalone/dp_security_matrix.json', __dir__)
    source = JSON.parse(File.read(path, encoding: 'UTF-8'))
    mutations = [
      ->(d) { d['nodes'] = [] },
      ->(d) { d['roles'][0]['code'] = nil },
      ->(d) { d['permissions'][0]['extra'] = true },
      ->(d) { d['permissions'][0]['focal'] = 'false' },
      ->(d) { d['permissions'] << d['permissions'][0].dup },
      ->(d) { d['permissions'].pop }
    ]
    mutations.each do |mutation|
      data = Marshal.load(Marshal.dump(source)); mutation.call(data)
      expect { SlimGraphR::Document.from_json(JSON.generate(data)) }.to raise_error(SlimGraphR::Error)
    end
  end

  it 'renders every authored cell, all level treatments, a used-only legend, and no connectors' do
    diagram = SlimGraphR.diagram(:dp_security_matrix) do
      role :a, 'Admins'; role :b, 'Readers'
      component :one, 'One'; component :two, 'Two'; component :three, 'Three'
      permission :one, :a, level: :admin
      permission :one, :b, level: :write
      permission :two, :a, level: :read
      permission :two, :b, level: :deny
      permission :three, :a, level: :unknown
      permission :three, :b, 'Read only', level: :read, note: 'critical', focal: true
    end
    svg = diagram.to_svg(id: 'matrix')
    doc = REXML::Document.new(svg)
    expect(REXML::XPath.match(doc, "//*[@data-security-cell]").size).to eq(6)
    expect(svg.scan(/data-security-level="(admin|write|read|deny|unknown)"/).flatten.uniq.sort).to eq(%w[admin deny read unknown write])
    expect(svg.scan(/data-security-legend-level="(admin|write|read|deny|unknown)"/).flatten).to eq(%w[admin write read deny unknown])
    expect(svg).to include('Admin', 'Read/write', 'Read', 'No access', 'Unknown', 'Read only', 'critical')
    expect(svg).not_to match(/<path\b|<line\b|<polyline\b|marker-end=/)
  end


  it 'rejects matrix collections on every other JSON type' do
    data = {
      type: 'architecture', nodes: [{ id: 'a' }], components: [], permissions: []
    }
    expect { SlimGraphR::Document.from_json(JSON.generate(data)) }
      .to raise_error(SlimGraphR::Error, /Only a DP security matrix accepts: components, permissions/)
  end

  it 'uses custom descriptions literally and generates complete accessible prose otherwise' do
    generated = build.to_svg(id: 'generated')[/<desc[^>]*>(.*?)<\/desc>/, 1]
    expect(generated).to include('Data administrators', 'DL-DataAdmins', 'Data engineers', 'Raw store', 'S3',
                                 'Aggregate catalog', 'SQL', 'Unknown', 'Select only', 'published aggregate')
    custom = build(description: 'Exact author description').to_svg(id: 'custom')
    expect(custom).to include('<desc id="custom-desc">Exact author description</desc>')
    expect(custom[/<desc[^>]*>(.*?)<\/desc>/, 1]).to eq('Exact author description')
  end

  it 'preserves all styles and light/dark themes' do
    SlimGraphR::Style.names.product(%i[light dark]).each do |style, theme|
      svg = build.with(style: style, theme: theme).to_svg(id: "#{style}-#{theme}")
      expect(svg).to include("data-sgr-style=\"#{style}\"", "data-sgr-theme=\"#{theme}\"")
      REXML::Document.new(svg)
    end
  end

  it 'raises actionable layout errors for measured role, component, cell, note, and legend text' do
    expect do
      SlimGraphR.diagram(:dp_security_matrix) do
        role :a, 'A' * 100; role :b, 'B'; component :x, 'X'; component :y, 'Y'
        permission :x, :a, level: :admin; permission :x, :b, level: :write
        permission :y, :a, level: :deny; permission :y, :b, level: :unknown
      end.to_svg
    end.to raise_error(SlimGraphR::LayoutError, /role.*shorten|split/i)
    expect do
      SlimGraphR.diagram(:dp_security_matrix) do
        role :a, 'A'; role :b, 'B'; component :x, 'X'; component :y, 'Y'
        permission :x, :a, level: :admin; permission :x, :b, level: :write
        permission :y, :a, 'L' * 100, level: :read, note: 'N' * 100, focal: true
        permission :y, :b, level: :unknown
      end.to_svg
    end.to raise_error(SlimGraphR::LayoutError, /permission.*shorten|split/i)
  end
end
