# frozen_string_literal: true
require 'slim_graph_r'

diagram = SlimGraphR.diagram :dp_security_matrix,
  title: 'Recorded platform access · 0.19 · 権限表',
  style: :editorial, theme: :light do
  role :admins, 'Data administrators', code: 'DL-DataAdmins'
  role :engineers, 'Data engineers', code: 'DL-DataEngineers'
  role :consumers, 'Data consumers'

  component :raw, 'Raw store', hint: 'S3'
  component :aggregate, 'Aggregate catalog', hint: 'SQL'
  component :reports, 'Published reports', hint: 'BI'

  permission :raw, :admins, level: :admin
  permission :raw, :engineers, level: :write
  permission :raw, :consumers, level: :deny
  permission :aggregate, :admins, level: :admin
  permission :aggregate, :engineers, level: :write
  permission :aggregate, :consumers, 'Select only', level: :read,
             note: 'published aggregate', focal: true
  permission :reports, :admins, level: :read
  permission :reports, :engineers, level: :read
  permission :reports, :consumers, level: :read
end

File.write('access-matrix.svg', diagram.to_svg)
diagram
