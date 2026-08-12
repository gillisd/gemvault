require_relative "gem_entry"
require_relative "manifest"
require_relative "timestamp"

module Gemvault
  ##
  # The manifest's on-disk notation: a header and one line per stored gem.
  #
  #   gemvault 3
  #   created 2026-08-12T16:05:55Z
  #
  #   foo 1.0.0 ruby 2026-08-12T16:05:55Z <sha256> 0
  #
  # A manifest is a table, not a document -- fixed-arity records of scalars,
  # with no nesting and no free text -- so it is written and read as one.
  # Every field comes from an alphabet that excludes whitespace: rubygems
  # validates gem names against <tt>/\A[a-zA-Z0-9._-]+\z/</tt>, versions and
  # platforms are drawn from the same characters, digests are hex, the flag is
  # a bit, and Gemvault::Timestamp keeps times space-free. That makes a line
  # unambiguous without quoting or escapes.
  #
  # The gain over a general notation is what a reader cannot be asked to do:
  # there is no recursion to exhaust the stack, no escape grammar, no
  # backtracking, and no library to load -- the last of which is what let a
  # <tt>require "json"</tt> in this path activate a gem version a project had
  # locked (issue #25).
  #
  # Reading validates every field, because a vault is a file that arrives from
  # elsewhere; writing does not, because the values come from value objects
  # this library constructed.
  module ManifestText
    # Raised when text is not a manifest this gemvault can read.
    class MalformedError < StandardError; end

    # The archive entry holding the manifest, and the one older gemvaults
    # wrote, recognized only to say so.
    FILENAME = "manifest".freeze
    LEGACY_FILENAME = "manifest.json".freeze

    MAGIC = "gemvault".freeze

    HEADER_LINES = 3

    # Field alphabets, composed into RECORD below.
    NAME = "[a-zA-Z0-9._-]+".freeze
    VERSION = "[0-9][0-9a-zA-Z.-]*".freeze
    PLATFORM = "[a-zA-Z0-9._-]+".freeze
    STAMP = "\\d{4}-\\d\\d-\\d\\dT\\d\\d:\\d\\d:\\d\\dZ".freeze
    DIGEST = "\\h{64}".freeze
    FLAG = "[01]".freeze

    # gemvault <version>
    MAGIC_LINE = /\A#{MAGIC} (\d+)\z/
    # created <timestamp>
    CREATED_LINE = /\Acreated (#{STAMP})\z/
    # name version platform stored-at sha256 encrypted
    RECORD = /\A(#{NAME}) (#{VERSION}) (#{PLATFORM}) (#{STAMP}) (#{DIGEST}) (#{FLAG})\z/

    ENCRYPTED = "1".freeze

    module_function

    # :call-seq:
    #   render(manifest) -> String
    #
    # +manifest+ as the text a vault stores.
    def render(manifest)
      header = ["#{MAGIC} #{Manifest::FORMAT_VERSION}", "created #{manifest.created_at}", ""]
      "#{(header + manifest.records.map { |record| record_line(record) }).join("\n")}\n"
    end

    def record_line(record)
      gem = record.gem
      [gem.name, gem.version, gem.platform, gem.created_at,
       record.sha256, record.encrypted ? ENCRYPTED : "0"].join(" ")
    end

    # :call-seq:
    #   parse(text) -> Manifest
    #
    # The Manifest +text+ describes. Raises MalformedError for anything this
    # gemvault did not write.
    def parse(text)
      lines = text.to_s.lines(chomp: true)
      version, created_at = read_header(lines)
      records = lines.drop(HEADER_LINES).map { |line| read_record(line) }
      Manifest.new(created_at:, records:, format_version: version)
    end

    def read_header(lines)
      raise MalformedError, "Not a gemvault manifest: no header" if lines.size < HEADER_LINES

      magic, created, separator = lines
      reject(separator, "expected a blank line after the header") unless separator.empty?
      [read_version(magic), read_created(created)]
    end

    def read_version(line) = Integer(capture(MAGIC_LINE, line, "expected a #{MAGIC} version line")[1], 10)

    def read_created(line) = capture(CREATED_LINE, line, "expected a created line")[1]

    def capture(pattern, line, expectation)
      pattern.match(line) || reject(line, expectation)
    end

    def read_record(line)
      fields = capture(RECORD, line, "expected a gem record")
      entry = GemEntry.new(name: fields[1], version: fields[2], platform: fields[3], created_at: fields[4])
      Manifest::StoredGem.new(gem: entry, sha256: fields[5], encrypted: fields[6] == ENCRYPTED)
    end

    # Truncated because a rejected line is arbitrary bytes from a file the
    # caller did not write, and it is about to be printed.
    def reject(line, reason)
      raise MalformedError, "Not a gemvault manifest (#{reason}): #{line.to_s[0, 60].inspect}"
    end

    private_class_method :record_line, :read_header, :read_version, :read_created,
                         :capture, :read_record, :reject
  end
end
