require 'benchmark'
require_relative '../../lib/slim_graph_r'
source = File.read(File.join(__dir__, 'diagram.rb'), encoding: 'UTF-8')
model = eval(source, binding, 'diagram.rb')
File.write(File.join(__dir__, 'generated.svg'), model.to_svg(id: 'benchmark'))
count = 100
seconds = Benchmark.realtime { count.times { model.to_svg(id: 'benchmark') } }
puts "Ruby #{RUBY_VERSION}: #{count} renders, #{(seconds * 1000 / count).round(3)} ms/render"
