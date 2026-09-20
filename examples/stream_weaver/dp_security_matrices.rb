# frozen_string_literal: true
require 'slim_graph_r/stream_weaver'

header1 'Access matrices'
md 'Bounded partial parity with [Cathryn Lavery’s pinned Diagram Design reference](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-dp-security-matrix.md).'
text 'Every role × component permission is explicit. Omission fails; unknown and denial are separate authored levels.'

%i[light dark].each do |theme|
  diagram :dp_security_matrix, title: "Recorded access · #{theme}", style: theme == :light ? :editorial : :ruby, theme: theme do
    role :admins, 'Data administrators', code: 'DL-DataAdmins'
    role :engineers, 'Data engineers'
    role :consumers, 'Data consumers'
    component :raw, 'Raw store', hint: 'S3'
    component :catalog, 'Aggregate catalog', hint: 'SQL'
    permission :raw, :admins, level: :admin
    permission :raw, :engineers, level: :write
    permission :raw, :consumers, level: :deny
    permission :catalog, :admins, level: :admin
    permission :catalog, :engineers, level: :unknown
    permission :catalog, :consumers, 'Select only', level: :read,
               note: 'published aggregate', focal: true
  end
end
