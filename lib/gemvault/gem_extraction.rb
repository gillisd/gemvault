require "rubygems/package"
require "tempfile"
require "stringio"
require_relative "vault"

module Gemvault
  # Shared vault behavior: turn gem bytes (stored or on disk) into gemspecs and
  # temporary files. Host classes must implement #gem_data(name, version,
  # platform:) and #gem_entries.
  module GemExtraction
    def with_gem_file(name, version, platform: "ruby")
      tmpfile = write_tempfile(gem_data(name, version, platform: platform))
      begin
        yield tmpfile.path
      ensure
        tmpfile.close unless tmpfile.closed?
        tmpfile.unlink
      end
    end

    def spec_from_blob(name, version, platform = "ruby")
      Gem::Package.new(StringIO.new(gem_data(name, version, platform: platform))).spec
    end

    def specs
      gem_entries.map { |entry| spec_from_blob(entry.name, entry.version, entry.platform) }
    end

    private

    def spec_from_gem_file(gem_path)
      Gem::Package.new(gem_path).spec
    rescue StandardError => e
      raise Vault::InvalidGemError, "Invalid gem file #{gem_path}: #{e.message}"
    end

    def write_tempfile(data)
      tmpfile = Tempfile.new(["vault_gem", ".gem"])
      tmpfile.binmode
      tmpfile.write(data)
      tmpfile.close
      tmpfile
    end
  end
end
