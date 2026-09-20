# frozen_string_literal: true
require 'slim_graph_r'

SlimGraphR.diagram(:treemap, title: 'Storage allocation', unit: 'GiB',
                   source_note: 'Storage ledger · 2026-09-01 · zeros retained') do
  item :images, 'Images', 80
  item :logs, 'Logs', 20, focal: true
  item :archive, 'Archive', 0
end
