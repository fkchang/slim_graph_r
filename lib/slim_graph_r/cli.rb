# frozen_string_literal: true
require 'optparse'
require 'tempfile'
require 'fileutils'
require_relative 'document'

module SlimGraphR
  class CLI
    class RubyContext
      attr_reader :result

      # String evaluation inherits local names; forwarding keeps DSL names unshadowed.
      def evaluate(...)
        instance_eval(...)
      end

      def diagram(type = :architecture, **options, &block)
        raise Error, 'Render one diagram per Ruby document' if @result
        @result = SlimGraphR.diagram(type, **options, &block)
      end
    end

    def self.run(args = ARGV, input: $stdin, output: $stdout, errors: $stderr)
      new(input, output, errors).run(args.dup)
    end

    def initialize(input, output, errors)
      @input, @output, @errors = input, output, errors
    end

    def run(args)
      command = args.shift
      case command
      when nil, 'help', '-h', '--help' then @output.puts(help); 0
      when '-v', '--version', 'version' then @output.puts("slimgraph #{VERSION}"); 0
      when 'types' then @output.puts(Diagram::TYPES.join("\n")); 0
      when 'styles' then @output.puts(Style.names.join("\n")); 0
      when 'install-skill' then install_skill(args)
      when 'render' then render(args)
      else raise OptionParser::InvalidArgument, "unknown command #{command.inspect}. Use slimgraph --help."
      end
    rescue OptionParser::ParseError => e
      @errors.puts("slimgraph: #{e.message}")
      2
    rescue Error, SystemCallError, EncodingError, SyntaxError => e
      @errors.puts("slimgraph: #{e.message}")
      1
    rescue StandardError => e
      @errors.puts("slimgraph: #{e.class}: #{e.message}")
      1
    end

    private

    def help
      <<~TEXT
        SlimGraphR #{VERSION} — express intention, get the picture.

        slimgraph render INPUT.rb|INPUT.json [-o OUTPUT.svg|OUTPUT.html]
        slimgraph render - --input-format json --format svg
        slimgraph types
        slimgraph styles
        slimgraph install-skill [--global] [--force]

        Render options:
          -o, --output PATH        Output file; default stdout (or use -)
          -f, --format FORMAT      svg or html; inferred from output extension
              --input-format TYPE ruby or json; inferred from input extension
              --style NAME         editorial, ruby, blueprint, mono, minimal
              --theme MODE         light, dark, auto
              --scale MODE         Timeline only: auto, date, ordered
              --force              Replace an existing output file

        Ruby documents execute as local Ruby code. JSON is validated data.
        Input limit: 1 MiB. Errors go to stderr; stdout contains only the result.
      TEXT
    end

    def install_skill(args)
      options = {}
      parser = OptionParser.new do |p|
        p.on('-g', '--global') { options[:global] = true }
        p.on('--force') { options[:force] = true }
        p.on('-h', '--help') { @output.puts(help); return 0 }
      end
      parser.parse!(args)
      raise OptionParser::InvalidArgument, "unexpected arguments: #{args.join(' ')}" unless args.empty?

      source = File.expand_path('../../skills/slim-graph-r', __dir__)
      raise Error, "Packaged skill is missing: #{source}" unless File.file?(File.join(source, 'SKILL.md'))

      roots = if options[:global]
        [File.expand_path('~/.agents/skills'), File.expand_path('~/.claude/skills')]
      else
        [File.join(Dir.pwd, '.agents', 'skills'), File.join(Dir.pwd, '.claude', 'skills')]
      end

      roots.each do |root|
        FileUtils.mkdir_p(root)
        install_skill_link(source, File.join(root, 'slim-graph-r'), force: options[:force])
      end

      scope = options[:global] ? 'globally' : 'in this project'
      @output.puts("Installed SlimGraphR diagram chooser #{scope}:")
      roots.each { |root| @output.puts("  #{File.join(root, 'slim-graph-r')}") }
      @output.puts('Agents can now choose one diagram family and load its reference on demand.')
      0
    end

    def install_skill_link(source, destination, force:)
      if File.symlink?(destination)
        return if File.expand_path(File.readlink(destination), File.dirname(destination)) == source
        File.unlink(destination)
      elsif File.exist?(destination)
        raise Error, "Skill destination already exists: #{destination}. Use --force to replace it." unless force
        FileUtils.rm_rf(destination)
      end
      FileUtils.ln_s(source, destination)
    end

    def render(args)
      options = {}
      parser = OptionParser.new do |p|
        p.on('-o PATH', '--output PATH') { |v| options[:output] = v }
        p.on('-f FORMAT', '--format FORMAT', %w[svg html]) { |v| options[:format] = v }
        p.on('--input-format TYPE', %w[ruby json]) { |v| options[:input_format] = v }
        p.on('--style NAME', Style.names.map(&:to_s)) { |v| options[:style] = v.to_sym }
        p.on('--theme MODE', %w[light dark auto]) { |v| options[:theme] = v.to_sym }
        p.on('--scale MODE', %w[auto date ordered]) { |v| options[:scale] = v.to_sym }
        p.on('--force') { options[:force] = true }
        p.on('-h', '--help') { @output.puts(help); return 0 }
      end
      parser.parse!(args)
      raise OptionParser::MissingArgument, 'one input file (or -) is required' unless args.size == 1
      path = args.first
      kind = options[:input_format] || (path == '-' ? 'json' : { '.rb' => 'ruby', '.json' => 'json' }[File.extname(path).downcase])
      raise OptionParser::InvalidArgument, 'input must end in .rb/.json, or specify --input-format' unless kind
      destination = options[:output]
      format = options[:format] || output_format(destination)
      source = path == '-' ? @input.read(Document::MAX_BYTES + 1) : File.binread(path, Document::MAX_BYTES + 1)
      raise Error, 'Input exceeds the 1 MiB document limit' if source.bytesize > Document::MAX_BYTES
      source = source.dup.force_encoding('UTF-8')
      raise Error, 'Input must be valid UTF-8' unless source.valid_encoding?
      model = kind == 'json' ? Document.from_json(source) : ruby_document(source, path)
      overrides = options.select { |key, _| %i[style theme scale].include?(key) }
      model = model.with(**overrides) unless overrides.empty?
      result = format == 'html' ? model.to_html : model.to_svg
      if destination && destination != '-'
        write_file(destination, result, force: options[:force])
      else
        @output.write(result)
        @output.write("\n")
      end
      0
    end

    def output_format(destination)
      return 'svg' if !destination || destination == '-'
      format = { '.svg' => 'svg', '.html' => 'html', '.htm' => 'html' }[File.extname(destination).downcase]
      format || raise(OptionParser::InvalidArgument, 'output must end in .svg/.html, or specify --format')
    end

    def ruby_document(source, path)
      previous_stdout = $stdout
      $stdout = @errors
      context = RubyContext.new
      value = context.evaluate(source, path == '-' ? '(stdin)' : File.expand_path(path), 1)
      model = context.result || value
      unless model.is_a?(Diagram) || model.is_a?(Quantitative::Chart) || model.is_a?(AreaConservation::Chart) || model.is_a?(Radial::Chart)
        raise Error, 'Ruby document must declare or return a SlimGraphR diagram'
      end
      model
    ensure
      $stdout = previous_stdout
    end

    def write_file(path, content, force:)
      # Link creates a new destination atomically; rename replaces only when requested.
      Tempfile.create(['.slimgraph-', '.tmp'], File.dirname(File.expand_path(path))) do |file|
        file.binmode
        file.write(content)
        file.flush
        file.chmod(0o666 & ~File.umask)
        if force
          File.rename(file.path, path)
        else
          File.link(file.path, path)
        end
      end
    rescue Errno::EEXIST
      raise Error, "Output already exists: #{path}. Use --force to replace it."
    end
  end
end
