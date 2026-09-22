# frozen_string_literal: true

require 'digest'
require 'json'
require 'open3'
require_relative '../spec_helper'

RSpec.describe 'Deterministic parity font capture' do
  ROOT_FONT_CAPTURE = File.expand_path('../..', __dir__)

  it 'pins each locally intercepted capture face and excludes it from the gem runtime payload' do
    manifest = JSON.parse(File.read(File.join(ROOT_FONT_CAPTURE, 'script/parity-fonts.json')))

    expect(manifest.fetch('schema')).to eq('slim_graph_r/parity-fonts-v1')
    expect(manifest.fetch('faces').map { |face| [face.fetch('family'), face.fetch('style')] }).to eq([
      ['Geist', 'normal'],
      ['Geist Mono', 'normal'],
      ['Instrument Serif', 'normal'],
      ['Instrument Serif', 'italic']
    ])
    manifest.fetch('faces').each do |face|
      path = File.join(ROOT_FONT_CAPTURE, face.fetch('path'))
      expect(Digest::SHA256.file(path).hexdigest).to eq(face.fetch('sha256'))
    end
    expect(File.read(File.join(ROOT_FONT_CAPTURE, 'slim_graph_r.gemspec'))).to include("'vendor/diagram-design/fonts/'")
  end

  it 'serves the pinned faces locally and makes a mismatched font hash fatal before capture' do
    output, status = Open3.capture2e('bash', File.join(ROOT_FONT_CAPTURE, 'bin/check-parity-fonts'))

    expect(status).to be_success, output
    expect(output).to include('four pinned faces served locally', 'fallback and hash mismatch are fatal')
  end
end
