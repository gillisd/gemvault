require "pathname"
require_relative "bundler_plugin_index"

module Gemvault
  ##
  # A bundler plugin registration whose recorded installation lives in a gem
  # home rather than a plugin root.
  #
  # Bundler's Gemfile-driven plugin installer skips extracting a plugin that
  # is already installed as an ordinary gem, and registers the gem home's
  # paths in the plugin index instead of populating the plugin root -- the
  # ambient state issue #13 documents. That registration works until the
  # recorded copy leaves the gem home (gem cleanup after an upgrade, a ruby
  # switch, an explicit uninstall), after which Bundler::Plugin.load_plugin
  # skips the plugin behind a warning that bundler/setup silences,
  # Plugin.source returns nil, and every Gemfile naming the source type dies
  # with NoMethodError inside SourceList#add_plugin_source (issue #31).
  #
  # Settling relocates the registration while the recorded copy is still
  # there: the payload and its installation record are copied into the plugin
  # root whose index registered the plugin, and the index is repointed at the
  # copy, which survives whatever later happens to the gem home. Directories
  # are created 0755 and files 0644 explicitly, because a copy inheriting
  # world-writable modes (umask oddities, default ACLs) is one RubyGems will
  # later refuse to replace.
  #
  # A registration recorded at a path with no installation record beside it
  # is a path: or git: plugin, or a source tree, and is deliberately left
  # alone: relocating one would detach a development flow from its tree.
  class AmbientRegistration
    PLUGIN = "bundler-source-vault".freeze

    # Relocates an ambient registration of +plugin+, when one exists, into the
    # plugin root that registered it. A machine this cannot be done on --
    # read-only roots, permission refusals -- is left as found.
    def self.settle(plugin = PLUGIN, roots: bundler_roots)
      of(plugin, roots: roots)&.settle
    rescue SystemCallError
      nil
    end

    def self.of(plugin, roots: bundler_roots)
      roots = roots.map { |root| Pathname(root) }

      roots.filter_map { |root| in_root(root, plugin, roots) }.first
    end

    def self.in_root(root, plugin, roots)
      index = BundlerPluginIndex.new(root)
      recorded = index.recorded_path(plugin) or return nil
      recorded = Pathname(recorded)
      return nil if roots.any? { |candidate| recorded.to_s.start_with?("#{candidate}/") }
      return nil unless installed_gem?(recorded)

      new(plugin: plugin, index: index, root: root, recorded: recorded,
          record: installation_record(recorded))
    end
    private_class_method :in_root

    # An installed gem's directory sits in <home>/gems with its record beside
    # it in <home>/specifications, by RubyGems' own install convention.
    def self.installed_gem?(recorded)
      recorded.directory? && installation_record(recorded).file?
    end
    private_class_method :installed_gem?

    def self.installation_record(recorded)
      recorded.parent.parent / "specifications" / "#{recorded.basename}.gemspec"
    end
    private_class_method :installation_record

    def self.bundler_roots
      return [] unless defined?(Bundler::Plugin)

      [Bundler::Plugin.root, Bundler::Plugin.global_root]
    end
    private_class_method :bundler_roots

    def initialize(plugin:, index:, root:, recorded:, record:)
      @plugin = plugin
      @index = index
      @root = root
      @recorded = recorded
      @record = record
    end
    private_class_method :new

    def settle
      materialize
      adopt(@record, specifications_dir / @record.basename)
      @index.repoint(@plugin, settled_dir)
    end

    private

    def settled_dir
      @root / "gems" / @recorded.basename
    end

    def specifications_dir
      ensure_dir(@root / "specifications")
    end

    def materialize
      return if settled_dir.directory?

      ensure_dir(@root / "gems")
      ensure_dir(settled_dir)
      @recorded.children.select(&:file?).each { |file| adopt(file, settled_dir / file.basename) }
    end

    def adopt(source, target)
      return if target.file?

      target.binwrite(source.binread)
      target.chmod(0o644)
    end

    def ensure_dir(dir)
      dir.mkdir(0o755) unless dir.directory?
      dir
    end
  end
end
