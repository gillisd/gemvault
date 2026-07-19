require "rubygems/package"
require "tempfile"
require "stringio"
require_relative "vault"

module Gemvault
  # Shared vault behavior: turn a gem entry (stored or on disk) into gemspecs
  # and temporary files. Host classes must implement #gem_data(entry) and
  # #gem_entries.
  module GemExtraction
    def with_gem_file(entry)
      data = gem_data(entry)
      Tempfile.create(["vault_gem", ".gem"]) do |tmpfile|
        tmpfile.binmode
        tmpfile.write(data)
        tmpfile.flush
        yield tmpfile.path
      end
    end

    def spec_from_blob(entry)
      bytes = gem_data(entry)
      io = StringIO.new(bytes)
      Gem::Package.new(io).spec
    end

    def specs
      gem_entries.map { |entry| spec_from_blob(entry) }
    end

    private

    def spec_from_gem_file(gem_path)
      begin
        Gem::Package.new(gem_path.to_s).spec
      rescue StandardError => e
        raise Vault::InvalidGemError, "Invalid gem file #{gem_path}: #{e.message}"
      end
    end
  end
end
