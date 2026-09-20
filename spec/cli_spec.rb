require 'spec_helper'
require 'open3'
require 'tmpdir'
require 'rbconfig'
require 'slim_graph_r/cli'
require 'stringio'

RSpec.describe 'slimgraph executable' do
  let(:root) { File.expand_path('..', __dir__) }
  let(:input) { File.join(root, 'examples/standalone/publishing.json') }
  def cli(*args, stdin: '')
    Open3.capture3(RbConfig.ruby, '-I', File.join(root, 'lib'), File.join(root, 'exe/slimgraph'), *args, stdin_data: stdin)
  end

  it 'prints useful discovery output' do
    out, err, status = cli('--help')
    expect(status.exitstatus).to eq(0)
    expect(out).to include('--style', '--force', 'JSON')
    expect(err).not_to include('slimgraph:')
    expect(cli('styles').first).to include('editorial', 'ruby', 'blueprint', 'mono', 'minimal')
    expect(cli('types').first).to include('dp_integration', 'dp_security_matrix', 'er', 'db_schema', 'uml_class', 'loop', 'wardley', 'polar', 'radar')
    expect(cli('--version').first).to include(SlimGraphR::VERSION)
  end

  it 'renders JSON stdin and applies presentation overrides' do
    out, err, status = cli('render', '-', '--style', 'minimal', '--theme', 'dark', stdin: File.read(input))
    expect(status.exitstatus).to eq(0), err
    expect(out).to start_with('<svg')
    expect(out).to include('data-sgr-style="minimal"', 'data-sgr-theme="dark"')
    expect(err).not_to include('slimgraph:')
    expect { REXML::Document.new(out) }.not_to raise_error
  end

  it 'accepts the concise Ruby document form and keeps ordinary Ruby output on stderr' do
    code = "puts 'a diagnostic'\ndiagram(:flowchart) { step :draft; step :publish; flow :draft, :publish }"
    out, err, status = cli('render', '-', '--input-format', 'ruby', stdin: code)
    expect(status.exitstatus).to eq(0), err
    expect(out).to start_with('<svg')
    expect(out).not_to include('a diagnostic')
    expect(err).to include('a diagnostic')
  end

  it 'parses bare source declarations inside the high-level DSL' do
    code = <<~RUBY
      diagram :high_level do
        phase(:sources) { source :postgres, type: :db }
        phase(:ingest) { component :nifi, role: 'COLL' }
        phase(:storage) { component :minio, role: 'STORE', focal: true }
        connect :postgres, :nifi
        connect :nifi, :minio
      end
    RUBY
    out, err, status = cli('render', '-', '--input-format', 'ruby', stdin: code)
    expect(status.exitstatus).to eq(0), err
    expect(out).to include('<svg', 'Postgres')
  end

  it 'renders journey-family Ruby and strict JSON through the CLI' do
    %w[journey story_map].each do |name|
      ruby_out, ruby_err, ruby_status = cli('render', File.join(root, "examples/standalone/#{name}.rb"))
      json_out, json_err, json_status = cli('render', File.join(root, "examples/standalone/#{name}.json"))
      expect(ruby_status.exitstatus).to eq(0), ruby_err
      expect(json_status.exitstatus).to eq(0), json_err
      marker = name.tr('_', '-')
      expect(ruby_out).to include(%(data-sgr-#{marker}="true"))
      expect(json_out).to include(%(data-sgr-#{marker}="true"))
    end
  end

  it 'renders equivalent DP integration Ruby and strict JSON through the CLI' do
    outputs = %w[rb json].map do |extension|
      out, err, status = cli('render', File.join(root, "examples/standalone/dp_integration.#{extension}"))
      expect(status.exitstatus).to eq(0), err
      expect(out).to include('data-sgr-dp-integration="true"', 'data-sgr-boundary-target="true"')
      out.force_encoding(Encoding::UTF_8)
      out.gsub(/sgr-[0-9a-f]{12}/, 'sgr-ID')
    end
    expect(outputs.first).to eq(outputs.last)
  end

  it 'renders equivalent DP security-matrix Ruby and strict JSON through the CLI' do
    outputs = %w[rb json].map do |extension|
      out, err, status = cli('render', File.join(root, "examples/standalone/dp_security_matrix.#{extension}"))
      expect(status.exitstatus).to eq(0), err
      expect(out).to include('data-sgr-dp-security-matrix="true"', 'data-security-level="deny"')
      expect(out).not_to include('marker-end=')
      out.force_encoding(Encoding::UTF_8)
      out.gsub(/sgr-[0-9a-f]{12}/, 'sgr-ID')
    end
    expect(outputs.first).to eq(outputs.last)
  end

  it 'renders equivalent ER Ruby and strict JSON through the CLI' do
    outputs = %w[rb json].map do |extension|
      out, err, status = cli('render', File.join(root, "examples/standalone/entity_relationships.#{extension}"))
      expect(status.exitstatus).to eq(0), err
      expect(out).to include('data-er="true"', 'data-er-cardinality="0..*"')
      expect(out).not_to include('marker-end=')
      out.force_encoding(Encoding::UTF_8).gsub(/sgr-[0-9a-f]{12}/, 'sgr-ID')
    end
    expect(outputs.first).to eq(outputs.last)
  end

  it 'renders equivalent UML-class Ruby and strict JSON through the CLI' do
    outputs = %w[rb json].map do |extension|
      out, err, status = cli('render', File.join(root, "examples/standalone/uml_class.#{extension}"))
      expect(status.exitstatus).to eq(0), err
      expect(out).to include('data-sgr-uml-class="true"', 'data-sgr-relation-kind="inheritance"',
                             'data-sgr-legend-kind="dependency"', 'data-sgr-display-scale="1.5"')
      out.force_encoding(Encoding::UTF_8).gsub(/sgr-[0-9a-f]{12}/, 'sgr-ID')
    end
    expect(outputs.first).to eq(outputs.last)
  end

  it 'renders equivalent Venn Ruby and strict JSON through the CLI' do
    outputs = %w[rb json].map do |extension|
      out, err, status = cli('render', File.join(root, "examples/standalone/venn.#{extension}"))
      expect(status.exitstatus).to eq(0), err
      expect(out).to include('data-sgr-venn="true"', 'data-sgr-venn-focal-clip="true"',
                             'area and population are not quantitative')
      out.force_encoding(Encoding::UTF_8).gsub(/sgr-[0-9a-f]{12}/, 'sgr-ID')
    end
    expect(outputs.first).to eq(outputs.last)
  end

  it 'renders equivalent loop Ruby and strict JSON through the CLI' do
    outputs = %w[rb json].map do |extension|
      out, err, status = cli('render', File.join(root, "examples/standalone/loop.#{extension}"))
      expect(status.exitstatus).to eq(0), err
      expect(out).to include('data-sgr-loop="true"', 'data-sgr-loop-direction="clockwise"',
                             'data-sgr-loop-closure="true"', 'data-sgr-loop-hub-gap="6"')
      out.force_encoding(Encoding::UTF_8).gsub(/sgr-[0-9a-f]{12}/, 'sgr-ID')
    end
    expect(outputs.first).to eq(outputs.last)
  end

  it 'renders equivalent Wardley Ruby and strict JSON through the CLI' do
    outputs = %w[rb json].map do |extension|
      out, err, status = cli('render', File.join(root, "examples/standalone/wardley.#{extension}"))
      expect(status.exitstatus).to eq(0), err
      expect(out).to include('data-sgr-wardley="true"', 'data-sgr-wardley-dependency=',
                             'data-sgr-wardley-movement=', 'not calculated scores')
      out.force_encoding(Encoding::UTF_8).gsub(/sgr-[0-9a-f]{12}/, 'sgr-ID')
    end
    expect(outputs.first).to eq(outputs.last)
  end

  it 'renders equivalent radial Ruby and strict JSON through the CLI' do
    %w[polar radar].each do |name|
      outputs = %w[rb json].map do |extension|
        out, err, status = cli('render', File.join(root, "examples/standalone/#{name}.#{extension}"))
        expect(status.exitstatus).to eq(0), err
        expect { REXML::Document.new(out) }.not_to raise_error
        expect(out).to include("data-#{name}-chart=\"true\"", 'AREA HAS NO MEANING')
        out.force_encoding(Encoding::UTF_8).gsub(/sgr-[0-9a-f]{12}/, 'sgr-ID')
      end
      expect(outputs.first).to eq(outputs.last)
    end
  end

  it 'renders the literal published high-level Ruby guide as a file' do
    code = File.read(File.join(root, 'docs/high-level.md'), encoding: 'UTF-8')[/```ruby\n(.*?)\n```/m, 1]
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'high-level.rb')
      File.write(path, code)
      out, err, status = Open3.capture3(RbConfig.ruby, '-I', File.join(root, 'lib'),
        File.join(root, 'exe/slimgraph'), 'render', path, chdir: dir)
      expect(status.exitstatus).to eq(0), err
      out.force_encoding(Encoding::UTF_8)
      normalize = ->(svg) { svg.gsub(/sgr-[0-9a-f]{12}/, 'sgr-ID').strip }
      expect(normalize.call(out)).to eq(normalize.call(File.read(File.join(dir, 'high-level.svg'), encoding: 'UTF-8')))
      expect(out).to include('LDAP · OIDC')
    end
  end

  it 'isolates evaluator locals and each document while allowing ordinary Ruby helpers' do
    runner = SlimGraphR::CLI.new(StringIO.new, StringIO.new, StringIO.new)
    code = <<~RUBY
      raise 'Evaluator locals leaked' unless local_variables.empty?
      raise 'Previous context leaked' if defined?(@document_marker) || respond_to?(:source)
      @document_marker = true
      def source(value); value; end
      def path(value); value; end
      def context(value); value; end
      def value(value); value; end
      def model(value); value; end
      def previous_stdout(value); value; end
      source :ok
      path :ok
      context :ok
      value :ok
      model :ok
      previous_stdout :ok
      SlimGraphR.diagram { node :a }
    RUBY
    2.times do
      expect(runner.send(:ruby_document, code, '-')).to be_a(SlimGraphR::Diagram)
    end
    expect(runner).not_to respond_to(:source)
    expect(Object.new).not_to respond_to(:source)
  end

  it 'preserves Ruby file locations, relative requires, and exception backtraces' do
    runner = SlimGraphR::CLI.new(StringIO.new, StringIO.new, StringIO.new)
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'document.rb')
      File.write(File.join(dir, 'helper.rb'), '# local helper')
      code = "require_relative 'helper'\nraise [__FILE__, __dir__].join('|')"
      stdout = $stdout
      expect { runner.send(:ruby_document, code, path) }.to raise_error(RuntimeError) { |error|
        expect(error.message).to eq("#{path}|#{dir}")
        expect(error.backtrace.first).to start_with("#{path}:2:")
      }
      expect($stdout).to equal(stdout)
      expect { runner.send(:ruby_document, 'raise __FILE__', '-') }.to raise_error(RuntimeError, '(stdin)')
    end
  end

  it 'still rejects missing or duplicate Ruby declarations' do
    ['42', 'diagram { node :a }; diagram { node :b }'].each do |code|
      out, err, status = cli('render', '-', '--input-format', 'ruby', stdin: code)
      expect(status.exitstatus).to eq(1)
      expect(out).to be_empty
      expect(err).to match(/must declare or return|one diagram per Ruby document/)
    end
  end

  it 'writes HTML atomically, preserves existing output, and replaces only with --force' do
    Dir.mktmpdir do |dir|
      destination = File.join(dir, 'result.html')
      _, err, status = cli('render', input, '-o', destination)
      expect(status.exitstatus).to eq(0), err
      expect(File.read(destination)).to start_with('<!doctype html>')
      File.write(destination, 'keep me')
      _, err, status = cli('render', input, '-o', destination)
      expect(status.exitstatus).to eq(1)
      expect(err).to include('--force')
      expect(File.read(destination)).to eq('keep me')
      expect(cli('render', input, '-o', destination, '--force').last.exitstatus).to eq(0)
      expect(Dir.children(dir)).to eq(['result.html'])
    end
  end

  it 'does not truncate an existing output when rendering fails' do
    Dir.mktmpdir do |dir|
      destination = File.join(dir, 'keep.svg')
      File.write(destination, 'keep me')
      _, _, status = cli('render', '-', '-o', destination, '--force', stdin: '{bad json')
      expect(status.exitstatus).to eq(1)
      expect(File.read(destination)).to eq('keep me')
    end
  end

  it 'reports usage, input and Ruby errors without successful output' do
    expect(cli('render').last.exitstatus).to eq(2)
    expect(cli('render', input, '--format', 'png').last.exitstatus).to eq(2)
    expect(cli('render', input, '--style', 'oops').last.exitstatus).to eq(2)
    expect(cli('render', 'missing.json').last.exitstatus).to eq(1)
    out, err, status = cli('render', '-', '--input-format', 'ruby', stdin: 'diagram do')
    expect(status.exitstatus).to eq(1)
    expect(out).to be_empty
    expect(err).to include('syntax error')
    out, err, status = cli('render', '-', stdin: "\xff".b)
    expect(status.exitstatus).to eq(1)
    expect(out).to be_empty
    expect(err).to include('UTF-8')
  end

  it 'overrides timeline scale and rejects invalid or misplaced scale options' do
    json = '{"type":"timeline","events":[{"date":"2026-02-01","label":"A"},{"date":"2026-01-01","label":"B"}]}'
    out, err, status = cli('render', '-', '--scale', 'ordered', stdin: json)
    expect(status.exitstatus).to eq(0), err
    expect(out).to include('spacing does not measure time')
    expect(cli('render', input, '--scale', 'bogus').last.exitstatus).to eq(2)
    expect(cli('render', input, '--scale', 'date').last.exitstatus).to eq(1)
  end
end
