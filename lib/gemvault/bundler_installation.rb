require "rbconfig"

module Gemvault
  # A bundler installation's `plugin.rb` on disk the file that holds
  # `Plugin.gemfile_install`. Discovered from rubygems, Ruby's stdlib
  # (for the default-gem bundler that ships with Ruby), and any vendored
  # copies under a given project root.
  class BundlerInstallation
    attr_reader :plugin_rb

    def self.discover(root: Pathname.pwd)
      root = Pathname(root)
      paths = system_paths + stdlib_paths + vendored_paths(root)
      paths.uniq.select(&:exist?).map { |path| new(path) }
    end

    class << self
      private

      def system_paths
        Gem::Specification.find_all_by_name("bundler").map { |spec|
          Pathname(spec.full_gem_path).join("lib/bundler/plugin.rb")
        }
      end

      def stdlib_paths
        %w[rubylibdir sitelibdir].filter_map { |key| RbConfig::CONFIG[key] }
                                 .map { |dir| Pathname(dir).join("bundler/plugin.rb") }
      end

      def vendored_paths(root)
        Pathname.glob(root.join("vendor/ruby/*/gems/bundler-*/lib/bundler/plugin.rb")) +
          Pathname.glob(root.join(".bundle/ruby/*/gems/bundler-*/lib/bundler/plugin.rb"))
      end
    end

    def initialize(plugin_rb)
      @plugin_rb = Pathname(plugin_rb)
    end

    def ==(other)
      other.is_a?(self.class) && plugin_rb == other.plugin_rb
    end
    alias eql? ==

    def hash
      plugin_rb.hash
    end

    def to_s
      plugin_rb.to_s
    end
  end
end
