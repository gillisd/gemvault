require "rubygems/package"
require "tempfile"
require "fileutils"
require_relative "manifest"

module Gemvault
  # The tar file backing a Tarvault. Reads named entries and rewrites the
  # whole archive atomically: tar has no index and the leading manifest entry
  # changes size on every mutation, so mutation means a full rewrite.
  class TarArchive
    def initialize(path)
      @path = path
    end

    def read(name)
      bytes = nil
      each_entry { |entry| bytes = entry.read if entry.full_name == name }
      bytes
    end

    def gem_pairs
      pairs = []
      each_entry do |entry|
        pairs << [entry.full_name, entry.read] unless entry.full_name == Manifest::FILENAME
      end
      pairs
    end

    def write(pairs)
      tmp = Tempfile.create(["tarvault", ".tar"], File.dirname(@path))
      write_entries(tmp, pairs)
      tmp.flush
      tmp.fsync
      tmp.close
      File.rename(tmp.path, @path)
    rescue StandardError
      cleanup(tmp)
      raise
    end

    private

    def each_entry(&)
      File.open(@path, "rb") do |io|
        Gem::Package::TarReader.new(io) { |reader| reader.each_entry(&) }
      end
    end

    def write_entries(io, pairs)
      Gem::Package::TarWriter.new(io) do |writer|
        pairs.each { |name, bytes| add_entry(writer, name, bytes) }
      end
    end

    def add_entry(writer, name, bytes)
      writer.add_file_simple(name, 0o644, bytes.bytesize) { |dest| dest.write(bytes) }
    end

    def cleanup(tmp)
      return unless tmp

      tmp.close unless tmp.closed?
      FileUtils.rm_f(tmp.path)
    end
  end
end
