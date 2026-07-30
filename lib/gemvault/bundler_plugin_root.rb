require "pathname"
require_relative "bundler_gemfile"

module Gemvault
  ##
  # Where Bundler keeps plugin data for a directory.
  #
  # Bundler::Plugin.root answers the project-local <tt>.bundle/plugin</tt> when
  # <tt>SharedHelpers.in_bundle?</tt> holds, and the global
  # <tt>~/.bundle/plugin</tt> when it does not. Since +in_bundle?+ is just
  # "was a Gemfile found", a project can own a plugin root that Bundler
  # declines to look in.
  class BundlerPluginRoot
    LOCAL_DIR = ".bundle/plugin".freeze

    def initialize(dir: Dir.pwd, gemfile: BundlerGemfile.new(dir: dir))
      @dir = Pathname(dir)
      @gemfile = gemfile
    end

    # The project's own plugin root, whether or not Bundler would consult it.
    def local
      @dir.expand_path / LOCAL_DIR
    end

    # Whether this project has a plugin root that Bundler currently ignores.
    #
    # bundler/inline installs plugins into <tt><cwd>/.bundle/plugin</tt>, having
    # set <tt>BUNDLE_GEMFILE</tt> to a bare "Gemfile" for the duration of the
    # script. A later command in that same directory sets no such variable and
    # finds no Gemfile on disk, so Bundler falls back to the global root and
    # reports the plugin as not installed -- while the entry sits here.
    def unreachable?
      !@gemfile.exist? && local.directory?
    end
  end
end
