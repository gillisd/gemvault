require "json"
require "openssl"
require_relative "gem_entry"

module Gemvault
  # The manifest.json stored as the first entry of a Tarvault. Records each
  # gem's identity, timestamp, and SHA256 digest so listing and integrity
  # checks never require reading every gem blob.
  class Manifest
    FILENAME = "manifest.json".freeze
    FORMAT_VERSION = "2".freeze
    DIGEST = "SHA256".freeze

    # One gem's metadata inside a manifest.
    Record = Struct.new(:name, :version, :platform, :created_at, :sha256, :encrypted, keyword_init: true) do
      def to_gem_entry
        GemEntry.new(name: name, version: version, platform: platform, created_at: created_at)
      end

      def filename
        to_gem_entry.filename
      end
    end

    def self.digest(bytes)
      OpenSSL::Digest.new(DIGEST).hexdigest(bytes)
    end

    def self.empty(created_at:)
      new(created_at: created_at, records: [])
    end

    def self.parse(json)
      data = JSON.parse(json)
      records = data.fetch("gems", []).map { |g| Record.new(**g.transform_keys(&:to_sym)) }
      new(created_at: data["created_at"], records: records)
    end

    attr_reader :records, :created_at

    def initialize(created_at:, records:)
      @created_at = created_at
      @records = records
    end

    def with(record)
      self.class.new(created_at: created_at, records: records + [record])
    end

    def without(dropped)
      self.class.new(created_at: created_at, records: records - dropped)
    end

    def find(name, version, platform)
      records.find { |r| r.name == name && r.version == version && r.platform == platform }
    end

    def gem_entries
      records.sort_by { |r| [r.name, r.version] }.map(&:to_gem_entry)
    end

    def to_json(*_args)
      JSON.pretty_generate(
        "vault_version" => FORMAT_VERSION,
        "format" => "tarvault",
        "created_at" => created_at,
        "gems" => records.map(&:to_h),
      )
    end
  end
end
