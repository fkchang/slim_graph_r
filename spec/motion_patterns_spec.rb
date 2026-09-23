# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'bounded motion patterns' do
  it 'renders the three compact five-step compositions at their authored dimensions' do
    expectations = {
      fan_in_queue: ['viewBox="0 0 1160 620"', 'FIFO QUEUE · CAPACITY 5', 'DEPTH 2 / 5', 'DEPTH 5 / 5'],
      paired_policy_trace: ['viewBox="0 0 1200 660"', 'TRACE A · INTERNAL RELEASE', 'DATA CLASS', 'NOT REACHED'],
      secure_paved_road: ['viewBox="0 0 1160 620"', 'DEVELOPMENT', 'BLOCKED AT FIREWALL', 'IMMUTABLE SIEM AUDIT']
    }

    expectations.each do |type, markers|
      presentation = SlimGraphR.motion_pattern(type)
      html = presentation.to_html
      expect(html).to include('data-step-count="5"', 'data-motion-action="replay"', *markers)
      expect(html.index('data-sgr-motion-controls')).to be < html.index('data-sgr-scroll-container')
    end
  end

  it 'replaces only the queue depth badge while the queue shell persists' do
    presentation = SlimGraphR.motion_pattern(:fan_in_queue)
    html = presentation.to_html
    final = presentation.to_svg(id: 'queue-final')

    expect(html).to include('DEPTH 2 / 5', 'DEPTH 5 / 5', 'data-motion-until="2"')
    expect(final).to include('FIFO QUEUE · CAPACITY 5', 'DEPTH 5 / 5')
    expect(final).not_to include('DEPTH 2 / 5', 'data-motion-item')
  end

  it 'keeps style and automatic dark-mode tokens inside the bounded renderer' do
    html = SlimGraphR.motion_pattern(:paired_policy_trace, style: :blueprint, theme: :auto).to_html
    expect(html).to include('data-sgr-style="blueprint"', 'data-sgr-theme="auto"', 'prefers-color-scheme:dark', '[data-sw-theme=dark]')
  end

  it 'validates pattern SVG IDs and keeps policy conclusions inside their reveal step' do
    policy = SlimGraphR.motion_pattern(:paired_policy_trace)
    expect { policy.to_svg(id: 'x" onload="alert(1)') }.to raise_error(SlimGraphR::Error, /SVG ID/)

    html = policy.to_html
    divergence = html[/<g [^>]*data-motion-key="node:\d+:rule_data_class"[\s\S]*?<\/g>/]
    expect(divergence).to include('data-step="3"', 'data-sgr-first-divergence="true"')
  end

  it 'keeps the blocked-route label clear of the paved-road audit card' do
    svg = SlimGraphR.motion_pattern(:secure_paved_road).to_svg(id: 'paved-final')
    label_x = svg[/data-sgr-blocked-label="true" x="(\d+)/, 1].to_i
    audit_x = svg[/data-sgr-audit-card="true"><rect x="(\d+)/, 1].to_i
    expect(label_x + 'BLOCKED AT FIREWALL'.length * 8).to be < audit_x
  end
end

RSpec.describe 'authored motion across existing families' do
  it 'targets sequence messages by authored ordinal, including repeated endpoints' do
    sequence = SlimGraphR.diagram(:sequence) do
      participant :client
      participant :service
      message :client, :service, 'Request'
      reply :service, :client, 'Response'
      message :client, :service, 'Follow-up'
    end
    animated = sequence.storyboard do
      reveal 1, message(1), 'Request'
      reveal 2, message(2), 'Response'
      reveal 3, message(3), 'Follow-up'
    end

    html = animated.to_html
    expect(html.scan('data-motion-item="true"').size).to eq(6) # connector + label per message
    expect(html).to include('data-motion-key="message:1:1"', 'data-motion-key="message:1:2"', 'data-motion-key="message:1:3"')
  end

  it 'targets explicit state transitions without implying every possible path' do
    graph = SlimGraphR.diagram(:state, direction: :right) do
      state :draft
      state :review
      state :published
      initial :draft
      final :published
      transition :draft, :review, on: 'submit'
      transition :review, :draft, on: 'revise'
      transition :review, :published, on: 'approve'
    end
    animated = graph.storyboard do
      reveal 1, :draft, 'Draft'
      reveal 2, :review, route(:draft, :review), 'Submit for review'
      reveal 3, :published, route(:review, :published), 'Approve publication'
    end
    expect(animated.to_html).to include('data-motion-key="node:5:draft"', 'data-motion-key="route:5:draft:6:review"')
  end

  it 'targets workflow activities and data-flow transfers with their handoffs' do
    process = SlimGraphR.diagram(:process) do
      lane :research, 'Research', key: 'R'
      lane :it, 'IT', key: 'IT'
      stage :design, 'Design'
      stage :build, 'Build', focal: true
      operation :draft, 'Draft', lane: :research, stage: :design, tool: 'Excel', output: 'FL'
      operation :app, 'Build app', lane: :it, stage: :build, tool: 'Ruby', input: 'FL', focal: true
      handoff :draft, :app
    end
    process_motion = process.storyboard do
      reveal 1, :draft, 'Draft'
      reveal 2, :app, route(:draft, :app), 'Build'
    end

    data = SlimGraphR.diagram(:data_flow) do
      role :engineering, 'Engineering', key: 'ENG'
      role :consumers, 'Consumers', key: 'CON'
      step :collect, 'Collect'
      step :publish, 'Publish', focal: true
      transfer :ingest, 'Ingest', role: :engineering, step: :collect, tool: 'SFTP', output: :dataset
      transfer :serve, 'Serve', role: :consumers, step: :publish, tool: 'SQL', input: :dataset, focal: true
      handoff :ingest, :serve, kind: :focal, label: 'DATA'
    end
    data_motion = data.storyboard do
      reveal 1, :ingest, 'Ingest'
      reveal 2, :serve, route(:ingest, :serve), 'Publish'
    end

    expect(process_motion.to_html).to include('data-motion-key="node:5:draft"', 'data-motion-key="route:5:draft:3:app"')
    expect(data_motion.to_html).to include('data-motion-key="node:6:ingest"', 'data-motion-key="route:6:ingest:5:serve"')
  end
end
