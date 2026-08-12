require "digest"
require_relative "gem_entry"
require_relative "json"

module Gemvault
  # The manifest.json stored as the first entry of a Tarvault. Records each
  # gem's identity, timestamp, and SHA256 digest so listing and integrity
  # checks never require reading every gem blob.
  class Manifest < Data.define(:created_at, :records, :format_version)
    FILENAME = "manifest.json".freeze
    FORMAT_VERSION = 2

    # One stored gem: its identity (a GemEntry) plus the integrity digest and
    # encryption flag the manifest keeps alongside it.
    class StoredGem < Data.define(:gem, :sha256, :encrypted)
      def self.from_h(hash)
        hash => { name:, version:, platform:, created_at:, sha256:, encrypted: }
        entry = GemEntry.new(name:, version:, platform:, created_at:)
        new(gem: entry, sha256:, encrypted:)
      end

      def filename = gem.filename

      def matches?(bytes) = Manifest.digest(bytes) == sha256

      def to_h
        {
          name: gem.name, version: gem.version, platform: gem.platform,
          created_at: gem.created_at, sha256:, encrypted:
        }
      end
    end

    def self.digest(bytes) = Digest::SHA256.hexdigest(bytes)

    def self.empty(created_at:) = new(created_at:, records: [])

    def self.parse(json)
      data = Json.parse(json)
      records = data.fetch(:gems, []).map { |gem| StoredGem.from_h(gem) }
      format_version = (data[:vault_version] || FORMAT_VERSION).to_i
      new(created_at: data[:created_at], records:, format_version:)
    end

    def initialize(created_at:, records:, format_version: FORMAT_VERSION)
      super
    end

    def with_record(record) = with(records: records + [record])

    def without(dropped) = with(records: records - dropped)

    def find(entry)
      records.find { |record| record.gem.same_identity_as?(entry) }
    end

    def matching(reference)
      records.select { |record| reference.matches?(record.gem) }
    end

    def size = records.size

    def gem_entries
      records.map(&:gem).sort_by { |gem| [gem.name, gem.version] }
    end

    def to_h
      {
        vault_version: FORMAT_VERSION,
        format: "tarvault",
        created_at:,
        gems: records.map(&:to_h),
      }
    end

    def to_json(*_args) = Json.pretty_generate(to_h)
  end
end
