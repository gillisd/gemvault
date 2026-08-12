require "digest"
require_relative "gem_entry"

module Gemvault
  # The index stored as the first entry of a Tarvault. Records each gem's
  # identity, timestamp, and SHA256 digest so listing and integrity checks
  # never require reading every gem blob. Its on-disk notation belongs to
  # Gemvault::ManifestText.
  class Manifest < Data.define(:created_at, :records, :format_version)
    FORMAT_VERSION = 3

    # One stored gem: its identity (a GemEntry) plus the integrity digest and
    # encryption flag the manifest keeps alongside it.
    class StoredGem < Data.define(:gem, :sha256, :encrypted)
      def filename = gem.filename

      def matches?(bytes) = Manifest.digest(bytes) == sha256
    end

    def self.digest(bytes) = Digest::SHA256.hexdigest(bytes)

    def self.empty(created_at:) = new(created_at:, records: [])

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
  end
end
