# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SlimGraphR::Motion do
  def diagram
    SlimGraphR.diagram(:architecture, title: 'Motion & intent') do
      node :source, 'Source'
      node :queue_open, 'Queue 2/5'
      node :queue_full, 'Queue 5/5'
      node :worker, 'Worker'
      edge :source, :queue_open, 'admitted'
      flow :queue_open, :queue_full, :worker
    end
  end

  def presentation
    diagram.storyboard do
      reveal 1, :source, :queue_open, route(:source, :queue_open), 'Steady <arrival>'
      reveal 2, :queue_full, route(:queue_open, :queue_full), 'Queue fills',
        replaces: [:queue_open, route(:source, :queue_open)]
      reveal 3, :worker, route(:queue_full, :worker), 'Worker drains'
    end
  end

  it 'keeps ordinary SVG unchanged and makes storyboard SVG the honest final frame' do
    ordinary = diagram.to_svg(id: 'same')
    final = presentation.to_svg(id: 'same')
    visible_final = final.sub(/<desc\b[^>]*>.*?<\/desc>/m, '')

    expect(ordinary).to include('Queue 2/5', 'Queue 5/5')
    expect(visible_final).not_to include('Queue 2/5', 'admitted', 'data-motion-item')
    expect(visible_final).to include('Queue 5/5', 'Worker')
    description = final[/<desc\b[^>]*>(.*?)<\/desc>/m, 1]
    expect(description).to include('Final frame of an ordered reveal', 'Step 3: Worker drains')
    expect(description).not_to include('Queue 2/5', 'admitted')
  end

  it 'renders cumulative semantic groups, replacement metadata, controls, and one shared player' do
    html = presentation.to_html

    source_key = SlimGraphR::Motion::Target.node(:source).key
    queue_key = SlimGraphR::Motion::Target.node(:queue_open).key
    source_route = SlimGraphR::Motion::Target.route(:source, :queue_open).key
    expect(html).to include(
      'data-sgr-motion-root', 'data-step-count="3"', %(data-motion-key="#{source_key}"),
      %(data-motion-key="#{source_route}"), %(data-motion-replaces="#{queue_key} #{source_route}"),
      'data-motion-until="2"', 'data-motion-action="replay"', 'SlimGraphRMotion'
    )
    expect(html).to include('aria-label="Step 1: Steady &lt;arrival&gt;"')
    expect(html.scan('<script>').size).to eq(1)
    expect(html.scan('[data-sgr-motion-root]{font-family').size).to eq(1)
  end

  it 'uses static HTML when explicitly requested' do
    html = presentation.to_html(motion: :static)
    visible_html = html.sub(/<desc\b[^>]*>.*?<\/desc>/m, '')
    expect(html).to include('Queue 5/5', 'Worker')
    expect(visible_html).not_to include('Queue 2/5')
    expect(html).not_to include('data-sgr-motion-root', '<script>')
  end

  it 'rejects dishonest or unrenderable storyboards with actionable errors' do
    expect { diagram.storyboard {} }.to raise_error(SlimGraphR::Error, /requires at least one/)
    expect do
      diagram.storyboard { reveal 2, :source, 'Starts at two' }
    end.to raise_error(SlimGraphR::Error, /contiguous sequence/)
    expect do
      diagram.storyboard { reveal 1, :missing, 'Missing' }.to_html
    end.to raise_error(SlimGraphR::Error, /were not rendered: missing/)
    expect do
      diagram.storyboard { reveal 1, :source, 'Duplicate'; reveal 2, :source, 'Again' }
    end.to raise_error(SlimGraphR::Error, /revealed more than once/)
    expect do
      diagram.storyboard do
        reveal 1, :source, 'Source', replaces: :worker
        reveal 2, :worker, 'Worker'
      end
    end.to raise_error(SlimGraphR::Error, /must be revealed before step 1/)
  end

  it 'ships reduced-motion, print, keyboard, exact-step, and visibility behavior' do
    html = presentation.to_html(motion: :reveal)
    expect(html).to include(
      'prefers-reduced-motion:reduce', '@media print', "params.get('motion') === 'step'",
      "event.key === 'ArrowLeft'", "event.key === 'End'", "event.key.toLowerCase() === 'r'",
      "document.addEventListener('visibilitychange'", "root.dataset.motionMode === 'reveal'",
      "item.setAttribute('aria-hidden', visible ? 'false' : 'true')", 'Number.isSafeInteger(requested)'
    )
  end

  it 'keeps routes unambiguous when endpoint IDs contain hyphens' do
    graph = SlimGraphR.diagram(:architecture) do
      node :'a-b'
      node :a
      node :c
      node :'b-c'
      edge :'a-b', :c
      edge :a, :'b-c'
    end
    first = SlimGraphR::Motion::Target.route(:'a-b', :c).key
    second = SlimGraphR::Motion::Target.route(:a, :'b-c').key
    animated = graph.storyboard do
      reveal 1, route(:'a-b', :c), 'First route'
      reveal 2, route(:a, :'b-c'), 'Second route', replaces: route(:'a-b', :c)
    end
    html = animated.to_html

    expect(first).not_to eq(second)
    expect(html.scan(%(data-motion-key="#{first}")).size).to eq(1)
    expect(html.scan(%(data-motion-key="#{second}")).size).to eq(1)
    expect(html).to include(%(data-motion-until="2"))
  end

  it 'renders all three executable semantic examples' do
    %w[fan_in_queue_animated policy_trace_animated secure_paved_road_animated].each do |name|
      model = eval(File.read(File.expand_path("../examples/standalone/#{name}.rb", __dir__), encoding: 'UTF-8'), binding, name)
      html = model.to_html
      expect(html).to include('data-step-count="5"', 'data-motion-item="true"', '<title ')
    end
  end
end
