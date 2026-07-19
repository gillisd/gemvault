require "rubygems/package"
require "tempfile"
require "pathname"
require_relative "archive_entry"

module Gemvault
  # The tar file backing a Tarvault. Reads named members and rewrites the whole
  # archive atomically: tar has no index and the leading manifest entry changes
  # size on every mutation, so mutation means a full rewrite.
  class Tarball
    def initialize(path)
      @path = Pathname(path)
    end

    def read(name)
      entries.find { |entry| entry.name == name }&.bytes
    end

    def entries
      each_entry.map { |member| ArchiveEntry.new(name: member.full_name, bytes: member.read) }
    end

    def write(entries)
      Tempfile.create(["tarvault", ".tar"], @path.dirname) do |tmp|
        write_entries(io: tmp, entries: entries)
        tmp.flush
        tmp.fsync
        tmp.close
        Pathname(tmp.path).rename(@path)
      end
    end

    private

    def each_entry(&block)
      return enum_for(:each_entry) unless block

      @path.open("rb") do |io|
        Gem::Package::TarReader.new(io) { |reader| reader.each_entry(&block) }
      end
    end

    def write_entries(io:, entries:)
      Gem::Package::TarWriter.new(io) do |writer|
        entries.each { |entry| add_entry(writer: writer, entry: entry) }
      end
    end

    def add_entry(writer:, entry:)
      writer.add_file_simple(entry.name, 0o644, entry.bytes.bytesize) { |dest| dest.write(entry.bytes) }
    end
  end
end
