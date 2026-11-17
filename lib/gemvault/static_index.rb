require "rubygems"

module Gemvault
  ##
  # A vault's gems laid out on disk as a static gem index: the directory
  # structure a gem server publishes, which RubyGems and Bundler read through
  # an ordinary <tt>file://</tt> source with no plugin involved.
  #
  # The index holds each <tt>.gem</tt> file, each gem's marshalled
  # specification, and the three listings a client fetches first.
  #
  # Asking where the index is and whether it is published touches nothing but
  # the filesystem, so both are safe inside a Bundler process. Publishing reads
  # gem packages, which loads zlib and the rest of what RubyGems needs for
  # that; VaultPublication keeps it out of the Bundler process.
  class StaticIndex
    MARSHAL = "Marshal.#{Gem.marshal_version}".freeze
    RELEASED = "specs.#{Gem.marshal_version}.gz".freeze
    LATEST = "latest_specs.#{Gem.marshal_version}.gz".freeze
    PRERELEASE = "prerelease_specs.#{Gem.marshal_version}.gz".freeze

    ##
    # The directory the index is laid out in.
    attr_reader :directory

    def initialize(directory)
      @directory = directory.to_s
    end

    ##
    # The address a gem source uses to read this index.
    def url
      "file://#{@directory}/"
    end

    ##
    # Whether a vault has already been published here. The released listing is
    # written last, so its presence marks a complete index.
    def published?
      File.file?(File.join(@directory, RELEASED))
    end

    ##
    # Writes every gem in +vault+ into the index.
    def publish(vault)
      specs = vault.gem_entries.map { |entry| store(vault, entry) }
      prerelease, released = specs.partition { |spec| spec.version.prerelease? }

      list(PRERELEASE, prerelease)
      list(LATEST, released)
      list(RELEASED, released)
    end

    private

    def store(vault, entry)
      write(File.join("gems", entry.filename), vault.gem_data(entry))

      vault.spec_from_blob(entry).tap do |spec|
        write(File.join("quick", MARSHAL, "#{spec.full_name}.gemspec.rz"), Gem.deflate(Marshal.dump(spec)))
      end
    end

    def list(listing, specs)
      tuples = specs.map { |spec| [spec.name, spec.version, spec.platform.to_s] }

      write(listing, Gem::Util.gzip(Marshal.dump(tuples)))
    end

    def write(relative_path, bytes)
      require "fileutils"

      file = File.join(@directory, relative_path)
      FileUtils.mkdir_p(File.dirname(file))
      File.binwrite(file, bytes)
    end
  end
end
