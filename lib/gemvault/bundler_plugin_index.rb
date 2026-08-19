require "pathname"

module Gemvault
  ##
  # Bundler's plugin index file inside a plugin root.
  #
  # The uninstall step of +gemvault doctor+ clears entries from this file, and
  # the reinstall that follows can fail for reasons unrelated to the plugin.
  # Snapshot and restore make that pair transactional: a repair that cannot
  # finish puts the index back instead of leaving the machine with no plugin
  # registered at all (issue #27).
  #
  # The plugin_paths section is scanned textually rather than parsed as YAML:
  # loading a YAML library into doctor's process invites the same
  # stdlib-activation conflicts as issue #25, and bundler's own emitter writes
  # one two-space-indented "name: path" line per plugin.
  class BundlerPluginIndex
    def initialize(root)
      @root = Pathname(root)
    end

    def file
      @root / "index"
    end

    # Whether plugin_paths currently lists +plugin+.
    def registered?(plugin)
      !record_line(plugin).nil?
    end

    # :call-seq:
    #   recorded_path(plugin) -> String or nil
    #
    # The installation path plugin_paths records for +plugin+, +nil+ when the
    # index does not list it. Bundler's emitter writes the value double-quoted.
    def recorded_path(plugin)
      record_line(plugin)&.slice(/: "(.*)"/, 1)
    end

    # Rewrites every path the index records for +plugin+ -- the plugin_paths
    # entry and the load_paths entry, the latter with bundler's trailing "/."
    # variant -- to +destination+. A plugin the index does not list is left
    # untouched.
    def repoint(plugin, destination)
      old = recorded_path(plugin) or return

      file.write(file.read.gsub(%r{"#{Regexp.escape(old)}(/\.)?"}) { %("#{destination}") })
    end

    # :call-seq:
    #   snapshot -> String or nil
    #
    # The index content as it stands, +nil+ when no index exists.
    def snapshot
      file.file? ? file.read : nil
    end

    # Puts the index back the way +snapshot+ recorded it; restoring +nil+
    # removes an index that did not exist at snapshot time.
    def restore(snapshot)
      return file.write(snapshot) if snapshot

      file.delete if file.exist?
    end

    private

    def record_line(plugin)
      plugin_paths.find { |line| line.match?(/\A\s{2}#{Regexp.escape(plugin)}:/) }
    end

    def plugin_paths
      return [] unless file.file?

      file.readlines
          .drop_while { |line| !line.start_with?("plugin_paths:") }
          .drop(1)
          .take_while { |line| line.start_with?(" ") }
    end
  end
end
