# Bundler can evaluate two installed copies of the shim in one process -- an
# upgrade resolving a newer bundler-source-vault while the index still names
# the old one -- and require_relative cannot deduplicate across paths, so a
# second copy would reopen the module and warn on every constant. The first
# copy wins, as it does for Bundler::Plugin::VaultSource in plugins.rb.
return if defined?(BundlerSourceVault::GemvaultLoadPath)

module BundlerSourceVault
  # Finds gemvault, and the runtime dependencies it needs, across every gem root
  # that could hold either, and puts their require paths on $LOAD_PATH.
  #
  # Bundler installs a plugin's dependencies alongside the plugin but does not
  # put them on the load path before loading plugins.rb -- see the "Currently
  # not done to avoid conflicts" comment in bundler/plugin.rb -- so the shim has
  # to find gemvault itself.
  #
  # $LOAD_PATH rather than activation, because activation cannot survive here:
  #
  #   bundler/runtime.rb  clean_load_path runs immediately before specs_for, and
  #                       resolution is what asks the vault source for specs.
  #   bundler/shared_helpers.rb
  #                       clean_load_path strips a $LOAD_PATH entry only when it
  #                       appears in loaded_gem_paths.
  #   bundler/rubygems_integration.rb
  #                       loaded_gem_paths is built from Gem.loaded_specs, so
  #                       activating is precisely what gets these paths removed
  #                       one line before they are needed; and stub_rubygems
  #                       sets Gem::Specification.all to the bundle's own specs,
  #                       reapplying it via Gem.post_reset, so under bundle exec
  #                       find_by_name cannot see outside the bundle and reset
  #                       will not restore it.
  #
  # Skipping activation also skips gemvault's dependencies, which is why they
  # are resolved here by hand. One that cannot be found is left out rather than
  # raising: command_kit is needed only by the CLI, and activation would have
  # aborted on it.
  module GemvaultLoadPath
    GEM = "gemvault".freeze
    SHIM = "bundler-source-vault".freeze
    VAULT_SOURCE = "bundler/plugin/vault_source.rb".freeze

    module_function

    def apply
      entries.each { |path| $LOAD_PATH.push(path) unless $LOAD_PATH.include?(path) }
    end

    # Development: loaded from within the gemvault source tree, where the gem is
    # not installed, so its lib has to lead the search.
    def source_tree_lib
      lib = shim_dir.parent.join("lib")
      lib if lib.join(VAULT_SOURCE).file?
    end

    # Registering these keeps the roots' specs discoverable to RubyGems, which is
    # what lets `bundle plugin install` see a gem it has just written into the
    # plugin root. It has to run on every evaluation, because it does not survive
    # one: Gem.clear_paths and Gem::Specification.reset, both of which Bundler
    # calls while configuring the bundle, recompute the dirs from Gem.path.
    def register_spec_dirs
      searched = Gem::Specification.dirs.map { |dir| Pathname(dir) }
      unsearched = install_roots.map { |root| root.join("specifications") }.select(&:directory?) - searched
      return refresh_stale_spec_cache if unsearched.empty?

      Gem::Specification.dirs = (searched + unsearched).map { |dir| dir.parent.to_s }
    end

    # The searched dirs are right but the spec cache predates this install:
    # `bundle plugin install` switches GEM_HOME to the plugin root and caches
    # specs during resolution, before gemvault lands there.
    def refresh_stale_spec_cache
      Gem::Specification.find_by_name(GEM)
    rescue Gem::LoadError
      Gem::Specification.reset
    end

    def entries
      spec = gemvault_spec
      return [] unless spec

      [*dependency_specs(spec).flat_map(&:full_require_paths), *spec.full_require_paths]
    end

    # Prefer the version the shim was released against, read off the shim's own
    # spec rather than its directory name: that name is a version only for a
    # plain `gem install`, and never for a source tree, a path: plugin, a git
    # plugin or a platform gem. With no spec to read, take the newest gemvault
    # present, which beats whichever the filesystem listed first.
    def gemvault_spec
      candidates = specs_named(GEM).select { |spec| vault_source_in?(spec) }
      pinned = candidates.select { |spec| pinned_requirement.satisfied_by?(spec.version) }

      (pinned.empty? ? candidates : pinned).max_by(&:version)
    end

    def pinned_requirement
      dependency = shim_spec&.dependencies&.find { |dep| dep.name == GEM }

      dependency&.requirement || Gem::Requirement.default
    end

    def shim_spec
      specs_named(SHIM).find { |spec| spec.full_gem_path == shim_dir.to_s }
    end

    def dependency_specs(spec)
      spec.runtime_dependencies.filter_map do |dependency|
        specs_named(dependency.name)
          .select { |candidate| dependency.requirement.satisfied_by?(candidate.version) }
          .max_by(&:version)
      end
    end

    def specs_named(name)
      install_roots
        .flat_map { |root| root.glob("specifications/#{name}-*.gemspec") }
        .filter_map { |file| Gem::Specification.load(file.to_s) }
        .select { |spec| spec.name == name }
    end

    def vault_source_in?(spec)
      spec.full_require_paths.any? { |path| Pathname(path).join(VAULT_SOURCE).file? }
    end

    # Installed, plugins.rb lives at <gem root>/gems/bundler-source-vault-<v>/,
    # and gemvault may sit in the same root: Bundler's local or global plugin
    # root, or a plain GEM_HOME. Both plugin roots count, because
    # Bundler::Plugin.root is the project-local root even when the plugin loads
    # from the global one.
    #
    # Gem.default_path is the load-bearing entry. Bundler skips installing a
    # plugin dependency that is already installed, so wherever `gem install
    # gemvault` has run the plugin root holds the shim alone; once the app bundle
    # is populated Bundler narrows GEM_PATH to it and the ambient gemvault drops
    # out of Gem.path. Gem.default_path is what RubyGems knows about its own gem
    # roots regardless of that narrowing. Reading roots back out of the
    # environment does not cover it -- rubies from rbenv, asdf, chruby, Homebrew
    # and distros export neither GEM_HOME nor GEM_PATH -- but it still matters
    # for the ones that export a root outside those defaults, like RVM.
    def install_roots
      candidate_roots
        .reject { |root| root.to_s.empty? }
        .map { |root| Pathname(root.to_s) }
        .uniq
        .select { |root| root.join("specifications").directory? }
    end

    def candidate_roots
      [shim_dir.parent.parent, *plugin_roots, *Gem.path, *Gem.default_path, *exported_roots]
    end

    def plugin_roots
      return [] unless defined?(Bundler::Plugin)

      [Bundler::Plugin.root, Bundler::Plugin.global_root]
    end

    def exported_roots
      return [] unless defined?(Bundler) && Bundler.respond_to?(:original_env)

      original = Bundler.original_env

      [original["GEM_HOME"], *original["GEM_PATH"].to_s.split(File::PATH_SEPARATOR)]
    end

    def shim_dir
      Pathname(__dir__)
    end
  end
end
