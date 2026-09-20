# frozen_string_literal: true

require 'bigdecimal'
require 'date'

if RUBY_ENGINE == 'opal'
  # Opal's BigDecimal implementation calls `.new` internally, while its own
  # `.new` emits a deprecation warning on every arithmetic operation. Route
  # that compatibility constructor to the supported Kernel factory before the
  # SlimGraphR core initializes any decimal constants.
  def BigDecimal.new(*args, **kwargs)
    BigDecimal(*args, **kwargs)
  end

  Date.const_set(:Error, ArgumentError) unless Date.const_defined?(:Error)
  unless Date.respond_to?(:iso8601)
    def Date.iso8601(value, start = Date::GREGORIAN)
      match = /\A(\d{4})-(\d{2})-(\d{2})\z/.match(value)
      raise ArgumentError, 'invalid date' unless match

      date = Date.new(match[1].to_i, match[2].to_i, match[3].to_i, start)
      raise ArgumentError, 'invalid date' unless date.iso8601 == value

      date
    end
  end
end
