# frozen_string_literal: true
module SlimGraphR
  module Text
    module_function

    def clean(value)
      text = value.to_s.encode('UTF-8')
      raise Error, 'Text must be valid UTF-8' unless text.valid_encoding?
      raise Error, 'Text contains invalid XML characters' if text.match?(/[\x00-\x08\x0b\x0c\x0e-\x1f\uFFFE\uFFFF]/)
      raise Error, 'Labels must be at most 300 characters' if text.length > 300
      text.freeze
    rescue EncodingError
      raise Error, 'Text must be valid UTF-8'
    end

    # Conservative font-independent budgeting, including combining marks and wide glyphs.
    def width(text, size = 14, font: :sans)
      text.each_char.sum do |char|
        code = char.ord
        if char.match?(/\p{M}/)
          0
        elsif code >= 0x1100 && (code <= 0x115f || code >= 0x2329 && code <= 0x232a ||
              code >= 0x2e80 && code <= 0xa4cf || code >= 0xac00 && code <= 0xd7af ||
              code >= 0xf900 && code <= 0xfaff || code >= 0xfe10 && code <= 0xfe6f ||
              code >= 0xff01 && code <= 0xff60 || code >= 0x1f000)
          size
        elsif font == :mono
          size * 0.64
        elsif char.match?(/[MW@%]/)
          size * 0.95
        else
          size * 0.62
        end
      end
    end

    def grid(number) = (number / 4.0).ceil * 4

    def wrap(text, budget = 192, size = 14, font: :sans)
      lines = []
      text.split("\n", -1).each do |paragraph|
        line = ''
        paragraph.split(/\s+/).each do |word|
          if !line.empty? && width("#{line} #{word}", size, font: font) > budget
            lines << line
            line = ''
          end
          characters = RUBY_ENGINE == 'opal' ? word.chars : word.scan(/\X/)
          characters.each do |char|
            if width(line + char, size, font: font) > budget
              lines << line.rstrip
              line = ''
            end
            line += char
          end
          line += ' '
        end
        lines << line.rstrip
      end
      lines.empty? ? [''] : lines
    end
  end
end
