require "rubygems/package"
require "tempfile"
require "stringio"

module Gemvault
  # Shared vault behavior: turn stored gem bytes into gemspecs and temporary
  # files. Host classes must implement #gem_data(name, version, platform:).
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

    private

    def write_tempfile(data)
      tmpfile = Tempfile.new(["vault_gem", ".gem"])
      tmpfile.binmode
      tmpfile.write(data)
      tmpfile.close
      tmpfile
    end
  end
end
