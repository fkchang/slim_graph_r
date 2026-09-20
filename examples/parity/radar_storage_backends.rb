# frozen_string_literal: true
require 'slim_graph_r'
module ParityFixtures
  module RadarStorageBackends
    module_function
    def diagram(theme: :light, style: :editorial)
      SlimGraphR.diagram(:radar, title: 'Storage backends · Capability radar', unit: 'score / 10', theme: theme, style: style) do
        scale min: 0, max: 10
        %w[Small-file\ handling Large-object\ reads Write\ throughput Operational\ simplicity Iceberg\ integration].each_with_index { |label, index| criterion "c#{index + 1}", label }
        entity :minio, 'MinIO', values: { c1: 9, c2: 8, c3: 9, c4: 9, c5: 9 }, focal: true
        entity :s3, 'Amazon S3', values: { c1: 6, c2: 10, c3: 9, c4: 5, c5: 8 }
        entity :ceph, 'Ceph', values: { c1: 7, c2: 7, c3: 7, c4: 4, c5: 6 }
        entity :gcs, 'Google Cloud Storage', values: { c1: 6, c2: 9, c3: 8, c4: 6, c5: 7 }
      end
    end
  end
end
