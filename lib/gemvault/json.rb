module Gemvault
  ##
  # Reads and writes the manifest's JSON without the json gem.
  #
  # On rubies that resolve <tt>require "json"</tt> through gem activation, a
  # require inside a Bundler-managed process activates the newest installed
  # json gem; when the project locks an older one, the process dies in
  # Bundler's check_for_activated_spec! blaming a version nobody asked for
  # (issue #25). The manifest is the only JSON gemvault touches at runtime,
  # so it is read and written here with no library at all -- the reasoning
  # that keeps BundlerPluginIndex from requiring yaml.
  #
  # The emitter matches the json gem's pretty_generate byte for byte for the
  # values a manifest holds, so vaults written before and after this class
  # existed are indistinguishable.
  module Json
    # Raised when manifest JSON cannot be read.
    class ParseError < StandardError; end

    # Control characters the escape tables need, spelled as codepoints so the
    # source file itself stays plain ASCII.
    BACKSPACE = 8.chr(Encoding::UTF_8).freeze
    FORMFEED = 12.chr(Encoding::UTF_8).freeze

    INDENT = "  ".freeze

    # Escapes the json gem also spells out; any other control character
    # becomes a \u00XX escape via #quote.
    WRITE_ESCAPES = {
      '"' => '\"', "\\" => "\\\\", BACKSPACE => '\b', FORMFEED => '\f',
      "\n" => '\n', "\r" => '\r', "\t" => '\t'
    }.freeze

    # Everything a JSON string cannot carry raw.
    UNSAFE = /["\\\x00-\x1f]/

    def self.parse(json) = Parser.new(json).parse

    def self.pretty_generate(value) = render(value, "")

    def self.render(value, indent)
      case value
      when Hash then render_object(value, indent)
      when Array then render_array(value, indent)
      when String, Symbol then quote(value.to_s)
      when nil then "null"
      else value.to_s
      end
    end

    def self.render_object(hash, indent)
      return "{}" if hash.empty?

      inner = indent + INDENT
      pairs = hash.map { |key, value| "#{inner}#{quote(key.to_s)}: #{render(value, inner)}" }
      "{\n#{pairs.join(",\n")}\n#{indent}}"
    end

    def self.render_array(array, indent)
      return "[]" if array.empty?

      inner = indent + INDENT
      "[\n#{array.map { |value| inner + render(value, inner) }.join(",\n")}\n#{indent}]"
    end

    def self.quote(string)
      escaped = string.gsub(UNSAFE) { |char| WRITE_ESCAPES[char] || format("\\u%04x", char.ord) }
      %("#{escaped}")
    end

    private_class_method :render, :render_object, :render_array, :quote

    # Recursive descent over the manifest's JSON, cursor anchored with \G.
    class Parser
      # Whitespace JSON permits between tokens; always matches, possibly empty.
      WHITESPACE = /\G[ \t\n\r]*/

      # A complete quoted string: unescaped characters or backslash pairs.
      STRING = /\G"((?:[^"\\\x00-\x1f]|\\.)*)"/

      # The three bare words JSON allows.
      LITERAL = /\G(?:true|false|null)/
      LITERALS = { "true" => true, "false" => false, "null" => nil }.freeze

      # JSON's number grammar; a fraction or exponent makes it a Float.
      NUMBER = /\G-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/
      FRACTION = /[.eE]/

      # A UTF-16 surrogate pair escaped as two \u units, decoded together.
      SURROGATE_PAIR = /\\u([dD][89abAB]\h{2})\\u([dD][c-fC-F]\h{2})/

      # Any single escape: a \u unit or one escaped character.
      ESCAPE = /\\(u\h{4}|.)/m
      ESCAPES = {
        '"' => '"', "\\" => "\\", "/" => "/", "b" => BACKSPACE,
        "f" => FORMFEED, "n" => "\n", "r" => "\r", "t" => "\t"
      }.freeze

      def initialize(json)
        @json = json
        @at = 0
      end

      def parse
        value = read_value
        skip_whitespace
        fail!("trailing characters") unless @at == @json.length
        value
      end

      private

      def read_value
        skip_whitespace
        case @json[@at]
        when "{" then read_object
        when "[" then read_array
        when '"' then read_string
        when nil then fail!("unexpected end of input")
        else read_literal_or_number
        end
      end

      def read_object
        @at += 1
        entries("}") { [read_key, read_value] }.to_h
      end

      def read_array
        @at += 1
        entries("]") { read_value }
      end

      def entries(closing)
        result = []
        return result if take?(closing)

        loop do
          result << yield
          break if take?(closing)

          fail!("expected ',' or '#{closing}'") unless take?(",")
        end
        result
      end

      def take?(char)
        skip_whitespace
        return false unless @json[@at] == char

        @at += 1
        true
      end

      def read_key
        skip_whitespace
        fail!("expected a quoted object key") unless @json[@at] == '"'

        key = read_string
        fail!("expected ':' after object key") unless take?(":")
        key.to_sym
      end

      def read_string
        match = STRING.match(@json, @at) or fail!("unterminated or malformed string")
        @at = match.end(0)
        unescape(match[1])
      end

      def unescape(text)
        return text unless text.include?("\\")

        text.gsub(SURROGATE_PAIR) { combined(Regexp.last_match) }
            .gsub(ESCAPE) { single(Regexp.last_match(1)) }
      end

      def combined(match)
        high, low = match.captures.map { |hex| hex.to_i(16) }
        [0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00)].pack("U")
      end

      def single(escape)
        return [escape[1..].to_i(16)].pack("U") if escape.start_with?("u")

        ESCAPES.fetch(escape) { fail!("unsupported escape \\#{escape}") }
      end

      def read_literal_or_number
        if (literal = LITERAL.match(@json, @at))
          @at = literal.end(0)
          return LITERALS.fetch(literal[0])
        end

        number = NUMBER.match(@json, @at) or fail!("unexpected character")
        @at = number.end(0)
        number[0].match?(FRACTION) ? Float(number[0]) : Integer(number[0], 10)
      end

      def skip_whitespace
        @at = WHITESPACE.match(@json, @at).end(0)
      end

      def fail!(reason)
        raise ParseError, "#{reason} at position #{@at}"
      end
    end
  end
end
