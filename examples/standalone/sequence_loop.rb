require 'slim_graph_r'

diagram = SlimGraphR.diagram :sequence, title: 'A worker earns its keep', style: :blueprint do
  participant :worker, emphasis: true
  participant :queue, kind: :store
  participant :metrics

  loop 'for each queued job' do
    message :worker, :queue, 'Poll for work'
    activate :queue do
      reply :queue, :worker, 'Next job'
    end
    activate :worker do
      message :worker, :worker, 'Process the job'
      activate :worker do
        notify :worker, :metrics, 'Record completion'
      end
    end
  end
  opt 'queue empty' do
    notify :queue, :worker, 'Wait for work'
  end
end

puts diagram.to_svg if $PROGRAM_NAME == __FILE__
diagram
