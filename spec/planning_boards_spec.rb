# frozen_string_literal: true
require 'spec_helper'
require 'slim_graph_r/document'

RSpec.describe 'planning-board diagrams' do
  def gantt(**options)
    SlimGraphR.diagram(:gantt, title: '0.15 plan', **options) do
      phase :foundation, 'Foundation' do
        task :calendar, 'Calendar scale', start: '2026-01-05', finish: '2026-01-16', focal: true
        task :board, 'Board model', start: '2026-01-12', finish: '2026-01-23'
      end
      milestone :cutover, 'Cutover', on: '2026-01-23', phase: :foundation
      marker :review, 'Review', on: '2026-01-16'
    end
  end

  def kanban(**options)
    SlimGraphR.diagram(:kanban, title: 'Platform work', **options) do
      column :backlog, 'Backlog' do
        card :api, 'API contract'
      end
      column :build, 'In progress', wip_limit: 1 do
        card :cache, 'Cache migration', state: :blocked, focal: true
        card :docs, 'Release notes', ticket: 'AVA-216', state: :waiting
      end
      column :done, 'Done' do
        card :lint, 'Lint cleanup', owner: 'nadia', state: :done
      end
    end
  end

  it 'fits the exact atlas plan while preserving date mapping and contained labels and bars' do
    scene = gantt(title: 'Platform launch').layout
    expect(scene.width).to eq(900)
    expect(gantt(title: 'Platform launch').to_svg(id: 'atlas-gantt')).to include(
      'viewBox="0 0 900 ', 'width="1350"', 'min-width:1350px'
    )
    expect(scene.tasks.map { |item| item[:x] }).to eq([200, 464.44444444444446])
    expect(scene.milestones.map { |item| item[:x] }).to eq([880])
    scene.tasks.each do |item|
      expect(item[:x]).to be >= scene.timeline_x
      expect(item[:x] + item[:width]).to be <= scene.timeline_x + scene.timeline_width
    end
    (scene.milestones + scene.markers).each do |item|
      left = item[:label_anchor] == 'start' ? item[:label_x] : item[:label_x] - item[:label_width]
      right = item[:label_anchor] == 'start' ? item[:label_x] + item[:label_width] : item[:label_x]
      expect(left).to be >= scene.timeline_x
      expect(right).to be <= scene.timeline_x + scene.timeline_width
    end
  end

  it 'builds deeply immutable dedicated Gantt and Kanban records in declaration order' do
    plan = gantt
    expect(plan.gantt_phases.map(&:id)).to eq(%w[foundation])
    expect(plan.gantt_tasks.map(&:id)).to eq(%w[calendar board])
    expect(plan.gantt_tasks.first.then { |item| [item.start, item.finish, item.phase, item.focal] }).to eq(
      ['2026-01-05', '2026-01-16', 'foundation', true]
    )
    board = kanban
    expect(board.kanban_columns.map(&:id)).to eq(%w[backlog build done])
    expect(board.kanban_columns[1].cards.map(&:id)).to eq(%w[cache docs])
    expect(board.kanban_columns[0].wip_limit).to be_nil
    expect(board.kanban_columns[0].cards.first.state).to eq(:default)
    [plan.gantt_phases, plan.gantt_tasks, plan.gantt_milestones, plan.gantt_markers, board.kanban_columns].each { |items| expect(items).to be_frozen }
    expect(board.kanban_columns).to all(satisfy { |column| column.frozen? && column.cards.frozen? && column.cards.all?(&:frozen?) })
  end

  it 'preserves enclosing builder context after rejected nesting and owns date string copies' do
    start_value = +'2026-01-05'
    finish_value = +'2026-01-06'
    gantt_errors = []
    plan = SlimGraphR.diagram(:gantt) do
      phase :outer do
        task :kept, start: start_value, finish: finish_value
        begin
          phase(:nested) {}
        rescue SlimGraphR::Error => error
          gantt_errors << error
        end
        begin
          milestone :inside, on: '2026-01-05'
        rescue SlimGraphR::Error => error
          gantt_errors << error
        end
      end
    end
    start_value << ' changed'
    finish_value << ' changed'
    expect(plan.gantt_tasks.first.then { |item| [item.start, item.finish, item.phase] }).to eq(
      ['2026-01-05', '2026-01-06', 'outer']
    )
    expect(start_value).not_to be_frozen
    expect(finish_value).not_to be_frozen
    expect(gantt_errors.map(&:message)).to include(match(/cannot nest/i), match(/top level/i))
    expect(plan.gantt_milestones).to be_empty

    kanban_errors = []
    board = SlimGraphR.diagram(:kanban) do
      column :outer do
        begin
          column(:nested) {}
        rescue SlimGraphR::Error => error
          kanban_errors << error
        end
        begin
          card :kept
        rescue SlimGraphR::Error => error
          kanban_errors << error
        end
      end
      column(:other) {}
    end
    expect(board.kanban_columns.first.cards.map(&:id)).to eq(['kept'])
    expect(kanban_errors.map(&:message)).to eq(['Kanban columns cannot nest'])
  end

  it 'keeps packaged Ruby and strict JSON byte-identical for both families' do
    root = File.expand_path('../examples/standalone', __dir__)
    %w[gantt kanban].each do |name|
      ruby = eval(File.read(File.join(root, "#{name}.rb"), encoding: 'UTF-8'), binding, name)
      json = SlimGraphR::Document.from_json(File.read(File.join(root, "#{name}.json"), encoding: 'UTF-8'))
      family = name == 'gantt' ? %i[gantt_phases gantt_tasks gantt_milestones gantt_markers] : %i[kanban_columns]
      family.each { |reader| expect(json.public_send(reader)).to eq(ruby.public_send(reader)) }
      expect(json.to_svg(id: "#{name}-parity")).to eq(ruby.to_svg(id: "#{name}-parity"))
    end
  end

  it 'validates complete Gregorian dates, leap days, and half-open task intervals' do
    expect do
      SlimGraphR.diagram(:gantt) { phase(:p) { task :leap, start: '2028-02-29', finish: '2028-03-01' } }
    end.not_to raise_error
    %w[2026-02-29 2026-2-03 2026-04-31 2026-01-01T00:00:00Z].each do |date|
      expect do
        SlimGraphR.diagram(:gantt) { milestone :bad, on: date }
      end.to raise_error(SlimGraphR::Error, /valid Gregorian YYYY-MM-DD/i)
    end
    %w[2026-01-05 2026-01-04].each do |finish|
      expect do
        SlimGraphR.diagram(:gantt) { phase(:p) { task :bad, start: '2026-01-05', finish: finish } }
      end.to raise_error(SlimGraphR::Error, /finish.*after start|half-open/i)
    end
  end

  it 'uses exact elapsed-day positions, an exclusive finish caption, and declaration-order rows' do
    svg = gantt.to_svg(id: 'calendar-geometry')
    expect(svg).to include('Task bars include start; finish date is excluded')
    expect(svg).to match(/data-sgr-gantt-task="calendar"[^>]*x="200"[^>]*width="415\.555/)
    expect(svg).to match(/data-sgr-gantt-task="board"[^>]*x="464\.444/)
    expect(svg).to match(/data-sgr-gantt-milestone="cutover"[^>]*data-sgr-date="2026-01-23"[^>]*data-sgr-x="880"/)
    expect(svg).to match(/data-sgr-gantt-marker="review"[^>]*data-sgr-x="615\.555/)
    expect(svg.index('data-sgr-gantt-task="calendar"')).to be < svg.index('data-sgr-gantt-task="board"')
    expect(svg).to include('2026-01-05', '2026-01-23')
  end

  it 'breaks a supplied marker line around the visible finish-exclusive caption without moving its date x' do
    plan = SlimGraphR.diagram(:gantt) do
      phase(:p) { task :span, start: '2026-01-05', finish: '2026-02-09' }
      marker :review, 'Review', on: '2026-01-16'
    end
    svg = plan.to_svg(id: 'marker-caption-clearance')
    expect(svg).to include('data-sgr-gantt-marker-line="review"', 'data-sgr-marker-segment="before-caption"',
                           'data-sgr-marker-segment="after-caption"')
    expect(svg).to match(/data-sgr-gantt-marker-line="review"[^>]*x1="413\.714286"[^>]*y2="41"/)
    expect(svg).to match(/data-sgr-gantt-marker-line="review"[^>]*x1="413\.714286"[^>]*y1="62"/)
  end

  it 'centers a milestone-only point domain and keeps close same-date points on separate tracks exact' do
    plan = SlimGraphR.diagram(:gantt, title: 'Release points') do
      phase :a, 'Alpha' do
      end
      phase :b, 'Beta' do
      end
      milestone :one, 'One', on: '2026-06-01', phase: :a
      milestone :two, 'Two', on: '2026-06-01', phase: :b
    end
    svg = plan.to_svg(id: 'point-domain')
    expect(svg.scan(/data-sgr-x="540"/).size).to be >= 2
    expect(svg).to include('data-sgr-domain-start="2026-06-01"', 'data-sgr-domain-finish="2026-06-01"')
  end

  it 'refuses subpixel bars and unresolved same-track point density without changing coordinates' do
    tiny = SlimGraphR.diagram(:gantt) do
      phase(:p) { task :tiny, start: '0001-01-01', finish: '0001-01-02' }
      marker :far, on: '9999-12-31'
    end
    expect { tiny.to_svg }.to raise_error(SlimGraphR::LayoutError, /under one CSS pixel.*narrow.*range/i)
    crowded = SlimGraphR.diagram(:gantt) do
      milestone :one, 'First long milestone', on: '2026-01-01'
      milestone :two, 'Second long milestone', on: '2026-01-02'
      marker :far, on: '2027-01-01'
    end
    expect { crowded.to_svg }.to raise_error(SlimGraphR::LayoutError, /same track.*overlap|split.*range/i)
  end

  it 'accepts close routed marker labels but rejects actual same-track milestone glyph overlap' do
    close_markers = SlimGraphR.diagram(:gantt) do
      phase(:p) { task :span, start: '2026-01-01', finish: '2026-03-11' }
      marker :a, 'A', on: '2026-01-10'
      marker :b, 'B', on: '2026-01-11'
    end
    svg = close_markers.to_svg(id: 'close-markers')
    expect(svg).to include('data-sgr-gantt-marker="a"', 'data-sgr-x="288.695652"',
                           'data-sgr-gantt-marker="b"', 'data-sgr-x="298.550725"')

    overlapping_diamonds = SlimGraphR.diagram(:gantt) do
      phase(:p) { task :span, start: '2026-01-01', finish: '2026-03-11' }
      milestone :a, 'A', on: '2026-01-10'
      milestone :b, 'B', on: '2026-01-11'
    end
    expect { overlapping_diamonds.to_svg }.to raise_error(SlimGraphR::LayoutError, /milestone diamonds overlap.*same track/i)
  end

  it 'draws honest Kanban counts, violations, every state, and a separate focal ring without connectors' do
    svg = kanban.to_svg(id: 'kanban-semantics')
    expect(svg).to include('data-sgr-column-count="1"', 'data-sgr-column-count="2"', 'data-sgr-wip-label="2/1"', 'data-sgr-wip-violation="true"')
    expect(svg).to include('data-sgr-card-state="default"', 'data-sgr-card-state="blocked"', 'data-sgr-card-state="waiting"', 'data-sgr-card-state="done"')
    expect(svg).to include('data-sgr-focal-ring="cache"', 'AVA-216', 'nadia')
    expect(svg).not_to include('marker-end=', 'data-sgr-workflow-connector', '+N more')
    expect(svg.index('data-sgr-column="backlog"')).to be < svg.index('data-sgr-column="build"')
    expect(svg.index('data-sgr-card="cache"')).to be < svg.index('data-sgr-card="docs"')
  end

  it 'accepts WIP breaches and multiple blocked cards while enforcing explicit geometry budgets' do
    board = SlimGraphR.diagram(:kanban) do
      column :a, wip_limit: 1 do
        card :one, state: :blocked
        card :two, state: :blocked
      end
      column :b do
      end
    end
    expect(board.to_svg.scan('data-sgr-card-state="blocked"').size).to eq(2)
    expect(board.to_svg).to include('data-sgr-wip-label="2/1"')
    crowded = SlimGraphR.diagram(:kanban) { column(:a) { 5.times { |i| card "c#{i}" } }; column(:b) {} }
    expect { crowded.to_svg }.to raise_error(SlimGraphR::LayoutError, /four cards.*split/i)
    long = SlimGraphR.diagram(:kanban) { column(:a) { card :x, 'W' * 150 }; column(:b) {} }
    expect { long.to_svg }.to raise_error(SlimGraphR::LayoutError, /card title.*fit|shorten/i)
  end

  it 'generates complete planning semantics when description is absent and honors author replacement' do
    gantt_desc = gantt.to_svg(id: 'gantt-generated-description')
    expect(gantt_desc).to include('finish date is excluded', 'Calendar scale', 'Cutover', 'Review')
    board_desc = kanban.to_svg(id: 'kanban-generated-description')
    expect(board_desc).to include('2 of limit 1, violation', 'Cache migration, blocked, focal', 'AVA-216', 'nadia')
    expect(gantt(description: 'Delivery view.').to_svg(id: 'gantt-custom-description')).not_to include('Gantt calendar plan')
    expect(gantt(description: 'Delivery view.').to_svg(id: 'gantt-custom-description')).to include('<desc id="gantt-custom-description-desc">Delivery view.</desc>')
    expect(kanban(description: 'Team census.').to_svg(id: 'kanban-custom-description')).not_to include('Kanban state census')
    expect(kanban(description: 'Team census.').to_svg(id: 'kanban-custom-description')).to include('<desc id="kanban-custom-description-desc">Team census.</desc>')
  end

  it 'renders every style in light and dark modes' do
    SlimGraphR::Style.names.product(%i[light dark]).each do |style, theme|
      [gantt(style: style, theme: theme), kanban(style: style, theme: theme)].each do |graph|
        svg = graph.to_svg(id: "#{graph.type}-#{style}-#{theme}")
        expect(svg).to include(%(data-sgr-style="#{style}"), %(data-sgr-theme="#{theme}"))
      end
    end
  end

  it 'rejects malformed, null, unknown, and cross-family JSON without inventing defaults' do
    gantt_data = JSON.parse(File.read(File.expand_path('../examples/standalone/gantt.json', __dir__), encoding: 'UTF-8'))
    kanban_data = JSON.parse(File.read(File.expand_path('../examples/standalone/kanban.json', __dir__), encoding: 'UTF-8'))
    invalid = [
      gantt_data.merge('nodes' => []),
      gantt_data.merge('milestones' => nil),
      gantt_data.merge('phases' => [gantt_data.fetch('phases').first.merge('tasks' => nil)]),
      gantt_data.merge('markers' => [{ 'id' => 'x', 'label' => 'X', 'on' => '2026-01-01', 'phase' => 'foundation' }]),
      kanban_data.merge('edges' => []),
      kanban_data.merge('columns' => [kanban_data.fetch('columns').first.merge('wip_limit' => nil)]),
      kanban_data.merge('columns' => [kanban_data.fetch('columns').first.merge('cards' => [{ 'id' => 'x', 'label' => 'X', 'ticket' => nil }])])
    ]
    invalid.each { |data| expect { SlimGraphR::Document.from_json(JSON.generate(data)) }.to raise_error(SlimGraphR::Error) }
  end
end
