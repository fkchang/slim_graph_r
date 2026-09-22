# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'rbconfig'
require 'tmpdir'
require 'fileutils'
require_relative '../../lib/slim_graph_r/university/provider'

RSpec.describe 'SlimGraphR University provider' do
  let(:source) { File.expand_path('../..', __dir__) }
  let(:stream_weaver_specification) { Gem::Specification.find_by_name('stream_weaver') }

  it 'keeps the canonical course, including its resolver, deeply immutable' do
    course = SlimGraphR::University::Provider::COURSE

    expect(course).to be_frozen
    expect(course.fetch(:demo_resolver)).to be_frozen
    expect(course.fetch(:steps)).to all(be_frozen)
    expect(course.fetch(:steps).flat_map(&:values)).to all(be_frozen)
    expect(course.fetch(:steps).first(2)).to all(satisfy { |step|
      step.fetch(:prompt).include?(SlimGraphR::University::Provider::OPEN_PAGE_HELPER) &&
        step.fetch(:prompt).include?("printf 'Installed SlimGraphR demo: %s\\n' \"$demo\"") &&
        step.fetch(:prompt).include?("printf 'Rendered page: %s\\n' \"$page\"")
    })
  end

  it 'keeps three lessons and sends learners to the complete diagram atlas' do
    steps = SlimGraphR::University::Provider::COURSE.fetch(:steps)

    expect(steps.map { |step| step.fetch(:number) }).to eq([1, 2, 3])
    expect(steps).to all(satisfy { |step| step.fetch(:prompt).include?('streamweaver diagrams') })
    expect(SlimGraphR::University::Provider::COURSE.fetch(:blurb)).to include('streamweaver diagrams')
  end

  it 'starts step three in one shell and tears down its Reader in a later shell' do
    Dir.mktmpdir('slim-graph-r-step-three') do |dir|
      fake_bin = File.join(dir, 'bin')
      FileUtils.mkdir_p(fake_bin)
      log = File.join(dir, 'commands.log')
      demo = File.join(dir, 'canvas demo.rb')
      File.write(demo, "# frozen_string_literal: true\n")
      File.write(File.join(fake_bin, 'open'), "#!/bin/sh\nprintf 'open:%s\\n' \"$1\" >> \"$TEST_LOG\"\n")
      File.write(File.join(fake_bin, 'streamweaver'), <<~'SH')
        #!/bin/sh
        printf '%s' "$1" >> "$TEST_LOG"
        printf '\n' >> "$TEST_LOG"
        case "$1" in
          university-demo) printf '%s\n' "$TEST_DEMO" ;;
          canvas-push) cat >/dev/null ;;
          panel) ;;
          canvas-read)
            printf 'canvas-read  1 file(s)  → http://127.0.0.1:4812/?file=0\n'
            trap 'printf "reader-stopped\\n" >> "$TEST_LOG"; exit 0' TERM
            while :; do sleep 1; done
            ;;
          export)
            shift
            source="$1"
            shift
            [ "$1" = '-o' ] || exit 12
            printf '<svg></svg>' > "$2"
            printf 'exported:%s\n' "$2" >> "$TEST_LOG"
            ;;
          canvas-close) ;;
        esac
      SH
      Dir.children(fake_bin).each { |name| FileUtils.chmod('+x', File.join(fake_bin, name)) }

      start_script = <<~SH
        set -eu
        #{SlimGraphR::University::Provider::OPEN_PAGE_HELPER}
        #{SlimGraphR::University::Provider::STEP_THREE_START}
        test -f "$exported_page"
      SH
      env = {
        'PATH' => "#{fake_bin}:#{ENV.fetch('PATH')}",
        'TMPDIR' => dir,
        'TEST_LOG' => log,
        'TEST_DEMO' => demo
      }
      _out, err, status = Open3.capture3(env, '/bin/bash', '-c', start_script)

      expect(status).to be_success, err
      state = File.join(dir, 'slim-graph-r-diagram-intent-reader.state')
      expect(File).to exist(state)
      reader_pid = File.read(state)[/reader_pid=(\d+)/, 1].to_i
      expect(reader_pid).to be_positive
      expect { Process.kill(0, reader_pid) }.not_to raise_error
      lines = File.readlines(log, chomp: true)
      expect(lines).to include('canvas-push', 'panel', 'canvas-read')
      expect(lines).not_to include('canvas-close')

      _out, err, status = Open3.capture3(env, '/bin/bash', '-c', SlimGraphR::University::Provider::STEP_THREE_CLEANUP)
      expect(status).to be_success, err
      expect(File).not_to exist(state)
      expect { Process.kill(0, reader_pid) }.to raise_error(Errno::ESRCH)

      lines = File.readlines(log, chomp: true)
      expect(lines).to include('canvas-close', 'reader-stopped')
      expect(lines.grep(/^open:/)).to eq([
        'open:http://127.0.0.1:4812/?file=0',
        "open:#{File.join(dir, 'diagram-intent.html')}"
      ])
      expect(lines.grep(/^exported:/)).to eq(["exported:#{File.join(dir, 'diagram-intent.html')}"])
    end
  end

  it 'uses open first, xdg-open next, and a successful printable fallback' do
    target = 'http://127.0.0.1:4812/?file=0'

    { 'open' => 'open', 'xdg-open' => 'xdg', nil => nil }.each do |command, expected|
      Dir.mktmpdir('slim-graph-r-opener') do |dir|
        fake_bin = File.join(dir, 'bin')
        FileUtils.mkdir_p(fake_bin)
        log = File.join(dir, 'opener.log')
        if command
          File.write(File.join(fake_bin, command), "#!/bin/sh\nprintf '#{expected}:%s\\n' \"$1\" >> \"$TEST_LOG\"\n")
          FileUtils.chmod('+x', File.join(fake_bin, command))
        end
        env = { 'PATH' => command ? fake_bin : '', 'TEST_LOG' => log }
        out, err, status = Open3.capture3(env, '/bin/bash', '-c', "#{SlimGraphR::University::Provider::OPEN_PAGE_HELPER}\nopen_page #{target}")

        expect(status).to be_success, err
        if expected
          expect(File.read(log, encoding: 'UTF-8').strip).to eq("#{expected}:#{target}")
        else
          expect(out).to include("Open this URL/path: #{target}")
          expect(File).not_to exist(log)
        end
      end
    end
  end

  it 'discovers an installed three-step Diagram Intent course and its packaged demos' do
    skip 'released StreamWeaver does not yet include external University courses' unless
      ENV['STREAM_WEAVER_SOURCE'] == 'git'
    course_catalog = File.join(stream_weaver_specification.full_gem_path,
                               'lib', 'stream_weaver', 'university', 'course_catalog.rb')
    expect(File).to exist(course_catalog)

    script = <<~'RUBY'
      def activate_installed(name)
        spec = Gem::Specification.find_all_by_name(name).find do |candidate|
          candidate.full_gem_path.start_with?(File.realpath(ENV.fetch('GEM_HOME')))
        end
        abort "missing isolated #{name} package" unless spec
        spec.activate
        abort "non-isolated #{name} package" unless Gem.loaded_specs.fetch(name).full_gem_path.start_with?(File.realpath(ENV.fetch('GEM_HOME')))
      end

      activate_installed('stream_weaver')
      activate_installed('slim_graph_r')
      allowed_roots = ENV.fetch('ISOLATED_ROOTS').split(File::PATH_SEPARATOR).map { |path| File.realpath(path) }
      Gem.loaded_specs.each_value do |spec|
        next if allowed_roots.any? { |root| spec.full_gem_path.start_with?(root) }

        abort "loaded #{spec.name} outside isolated roots: #{spec.full_gem_path}"
      end
      ENV.fetch('ISOLATED_DEPENDENCIES').split(',').each do |name|
        matches = Gem::Specification.find_all_by_name(name)
        abort "missing isolated dependency #{name}" unless matches.any? do |spec|
          spec.full_gem_path.start_with?(File.realpath(ENV.fetch('GEM_HOME')))
        end
      end
      require 'stream_weaver/university/course_catalog'
      require 'stream_weaver/canvas/bridge'
      require 'stream_weaver/canvas/reader'
      require 'stream_weaver/cli'
      require 'stream_weaver/export/html_exporter'
      require 'stringio'

      course = StreamWeaver::University::CourseCatalog.fetch('diagram-intent')
      abort 'wrong course title' unless course.title == 'Diagram Intent with SlimGraphR'
      abort 'wrong steps' unless course.steps.map { |step| step[:number] } == [1, 2, 3]
      abort 'mutable steps' unless course.steps.frozen? && course.steps.all?(&:frozen?)

      demos = %w[standalone semantic canvas].to_h { |name| [name, course.demo_resolver.call(name)] }
      abort 'missing packaged demo' unless demos.values.all? { |path| File.file?(path) }
      abort 'demo escaped the installed gem' unless demos.values.all? { |path| path.include?('/slim_graph_r-') }

      original_stdout = $stdout
      $stdout = StringIO.new
      StreamWeaver::CLI.university_demo(%w[canvas --course diagram-intent])
      selected_demo = $stdout.string.strip
      $stdout = original_stdout
      abort 'CLI selected the wrong demo' unless selected_demo == demos.fetch('canvas')

      source = File.read(demos.fetch('canvas'), encoding: 'UTF-8')
      live = StreamWeaver::Canvas::Bridge.new.send(:render_dsl, source, session_name: 'diagram-intent')
      abort "live render failed: #{live.error}" if live.error
      reopened = StreamWeaver::Canvas::Reader.render_doc(source).html
      exported = StreamWeaver::Export::HtmlExporter.from_dsl(source).to_html
      abort 'missing diagram output' unless [live.html, reopened, exported].all? { |html| html.include?('<svg') }

      puts [course.id, course.title, demos.keys.join(','), StreamWeaver::Extensions.registered?(:slim_graph_r)].join('|')
    RUBY

    Dir.mktmpdir('slim-graph-r-university-provider') do |gem_home|
      ruby_default_path = Gem.default_path.last
      weaver_specification = stream_weaver_specification
      env = {
        'GEM_HOME' => gem_home,
        'GEM_PATH' => [gem_home, ruby_default_path].join(File::PATH_SEPARATOR),
        'ISOLATED_ROOTS' => [gem_home, ruby_default_path].join(File::PATH_SEPARATOR),
        'ISOLATED_DEPENDENCIES' => weaver_specification.runtime_dependencies.map(&:name).join(','),
        'RUBYOPT' => nil,
        'RUBYLIB' => nil,
        'BUNDLE_GEMFILE' => nil,
        'BUNDLE_BIN_PATH' => nil
      }
      expect(env.fetch('GEM_PATH').split(File::PATH_SEPARATOR)).to eq([gem_home, Gem.default_path.last])
      build_env = env.merge('GEM_PATH' => Gem.path.join(File::PATH_SEPARATOR))
      command = [
        RbConfig.ruby, '-e', <<~RUBY
          require 'rubygems/package'
          require 'rubygems/installer'
          slim = Gem::Specification.load(#{File.join(source, 'slim_graph_r.gemspec').inspect})
          weaver = Gem::Specification.load(#{stream_weaver_specification.loaded_from.inspect})
          package_dir = File.join(ENV.fetch('GEM_HOME'), 'packages')
          Dir.mkdir(package_dir)
          dependencies = {}
          collect = lambda do |spec|
            spec.runtime_dependencies.each do |dependency|
              next if %w[slim_graph_r stream_weaver].include?(dependency.name)

              candidate = Gem::Specification.find_all_by_name(dependency.name, dependency.requirement)
                                        .reject(&:default_gem?).max_by(&:version)
              abort "missing cached dependency \#{dependency.name}" unless candidate
              next if dependencies.key?(candidate.full_name)

              dependencies[candidate.full_name] = candidate
              collect.call(candidate)
            end
          end
          collect.call(weaver)
          dependencies.values.sort_by(&:full_name).each do |dependency|
            cache = dependency.cache_file
            abort "missing cached gem \#{dependency.full_name}" unless File.file?(cache)
            Gem::Installer.at(cache, install_dir: ENV.fetch('GEM_HOME'), wrappers: false,
                              document: [], ignore_dependencies: true).install
          end
          [slim, weaver].each do |spec|
            installed_cache = spec.name == 'stream_weaver' &&
              spec.full_gem_path.start_with?(File.join(Gem.dir, 'gems')) && File.file?(spec.cache_file)
            package = if installed_cache
              spec.cache_file
            else
              root = File.dirname(spec.loaded_from)
              File.join(package_dir, "\#{spec.full_name}.gem").tap do |target|
                Dir.chdir(root) { Gem::Package.build(spec, false, false, target) }
              end
            end
            Gem::Installer.at(package, install_dir: ENV.fetch('GEM_HOME'), wrappers: false, document: []).install
          end
        RUBY
      ]
      _out, err, status = Bundler.with_unbundled_env { Open3.capture3(build_env, *command) }
      expect(status).to be_success, err

      out, err, status = Bundler.with_unbundled_env { Open3.capture3(env, RbConfig.ruby, '-e', script) }
      expect(status).to be_success, "#{out}\n#{err}"
      expect(out.strip).to eq('diagram-intent|Diagram Intent with SlimGraphR|standalone,semantic,canvas|true')
    end
  end
end
