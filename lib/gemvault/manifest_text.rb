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
  # elsewhere. Writing trusts the values this library computed or normalized
  # (digests, flags, times through Gemvault::Timestamp) -- but a gem's
  # identity arrives in a gem file this library did not write, and
  # <tt>Gem::Package#spec</tt> never validates it, so a vault asks
  # unwritable_field before admitting a gem.
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
    MAGIC_LINE = /\A#{MAGIC} (?<version>\d+)\z/
    # created <timestamp>
    CREATED_LINE = /\Acreated (?<created_at>#{STAMP})\z/
    # A record line's fields, in the order the line carries them.
    RECORD_FIELDS = { name: NAME, version: VERSION, platform: PLATFORM,
                      stored_at: STAMP, sha256: DIGEST, encrypted: FLAG }.freeze
    RECORD = /\A#{RECORD_FIELDS.map { |field, alphabet| "(?<#{field}>#{alphabet})" }.join(" ")}\z/

    # The spec-supplied alphabets anchored singly, for asking whether one
    # field fits before a record is written.
    IDENTITY_ALPHABETS = { name: /\A#{NAME}\z/, version: /\A#{VERSION}\z/, platform: /\A#{PLATFORM}\z/ }.freeze

    ENCRYPTED = "1".freeze

    # The lines every manifest opens with: the format version the writing
    # gemvault declared, the vault's creation time, and a blank separator.
    class Header < Data.define(:format_version, :created_at)
      def lines = ["#{MAGIC} #{format_version}", "created #{created_at}", ""]
    end

    module_function

    # :call-seq:
    #   render(manifest) -> String
    #
    # +manifest+ as the text a vault stores.
    def render(manifest)
      header = Header.new(format_version: Manifest::FORMAT_VERSION, created_at: manifest.created_at)
      "#{(header.lines + manifest.records.map { |record| record_line(record) }).join("\n")}\n"
    end

    def record_line(record)
      gem = record.gem
      [gem.name, gem.version, gem.platform, gem.created_at,
       record.sha256, record.encrypted ? ENCRYPTED : "0"].join(" ")
    end

    # :call-seq:
    #   unwritable_field(entry) -> Symbol or nil
    #
    # The first of +entry+'s identity fields holding a value outside its
    # alphabet, or nil when a record for +entry+ would read back intact.
    def unwritable_field(entry)
      IDENTITY_ALPHABETS.each_key.find { |field| !IDENTITY_ALPHABETS[field].match?(entry.public_send(field)) }
    end

    # :call-seq:
    #   parse(text) -> Manifest
    #
    # The Manifest +text+ describes. Raises MalformedError for anything outside
    # the notation above; the version a well-formed header declares is returned
    # as parsed, readability being Vault.assert_readable!'s question.
    def parse(text)
      lines = text.to_s.lines(chomp: true)
      header = read_header(lines)
      records = lines.drop(HEADER_LINES).map { |line| read_record(line) }
      Manifest.new(created_at: header.created_at, records:, format_version: header.format_version)
    end

    def read_header(lines)
      raise MalformedError, "Not a gemvault manifest: no header" if lines.size < HEADER_LINES

      magic, created, separator = lines
      reject(separator, reason: "expected a blank line after the header") unless separator.empty?
      Header.new(format_version: read_version(magic), created_at: read_created(created))
    end

    def read_version(line)
      Integer(capture(line, pattern: MAGIC_LINE, expecting: "expected a #{MAGIC} version line")[:version], 10)
    end

    def read_created(line) = capture(line, pattern: CREATED_LINE, expecting: "expected a created line")[:created_at]

    def capture(line, pattern:, expecting:)
      pattern.match(line) || reject(line, reason: expecting)
    end

    def read_record(line)
      fields = capture(line, pattern: RECORD, expecting: "expected a gem record")
      entry = GemEntry.new(name: fields[:name], version: fields[:version],
                           platform: fields[:platform], created_at: fields[:stored_at])
      Manifest::StoredGem.new(gem: entry, sha256: fields[:sha256], encrypted: fields[:encrypted] == ENCRYPTED)
    end

    # Truncated because a rejected line is arbitrary bytes from a file the
    # caller did not write, and it is about to be printed.
    def reject(line, reason:)
      raise MalformedError, "Not a gemvault manifest (#{reason}): #{line.to_s[0, 60].inspect}"
    end

    private_class_method :record_line, :read_header, :read_version, :read_created,
                         :capture, :read_record, :reject
  end
end
