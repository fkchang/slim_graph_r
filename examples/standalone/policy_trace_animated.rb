# frozen_string_literal: true
require 'slim_graph_r'

diagram = SlimGraphR.diagram(:flowchart, title: 'Policy trace: first divergence', style: :ruby) do
  start :identity, '1 · Identity bound · PASS / PASS'
  step :audience, '2 · Internal audience · PASS / PASS'
  step :divergence, '3 · Device trusted? · PASS / FAIL', emphasis: true
  step :later, '4 · Region allowed · SKIPPED / NOT REACHED'
  finish :outcomes, '5 · PERMIT / DENY'
  flow :identity, :audience, :divergence, :later, :outcomes
end

diagram.storyboard do
  reveal 1, :identity, 'Identity binding passes for both traces'
  reveal 2, :audience, route(:identity, :audience), 'Internal audience passes for both traces'
  reveal 3, :divergence, route(:audience, :divergence), 'Device trust is the first divergence'
  reveal 4, :later, route(:divergence, :later), 'The later rule is skipped or not reached'
  reveal 5, :outcomes, route(:later, :outcomes), 'The traces finish permitted and denied'
end
