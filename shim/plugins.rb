# Bundler installs plugin dependencies (here: gemvault) alongside the plugin but
# does not put them on the load path before loading plugins.rb -- see the
# "Currently not done to avoid conflicts" comment in bundler/plugin.rb. So this
# file has to find gemvault itself before requiring the vault source.
#
# Installed, this file lives at <gem root>/gems/bundler-source-vault-<v>/, and
# gemvault may sit in the same root: Bundler's local or global plugin root, or a
# plain GEM_HOME when installed with `gem install`. Bundler's plugin roots are
# also candidates because `Bundler::Plugin.root` is the project-local root even
# when the plugin actually loads from the global one. Registering those roots
# with Gem::Specification keeps their specs discoverable to RubyGems; the
# require itself is satisfied from $LOAD_PATH further down.
#
# This runs on every evaluation, before the guard below, because it does not
# survive one: `Gem.clear_paths` and `Gem::Specification.reset` -- both of which
# Bundler calls while configuring the bundle -- discard whatever was registered
# here and recompute the dirs from Gem.path.
plugin_roots = defined?(Bundler::Plugin) ? [Bundler::Plugin.root, Bundler::Plugin.global_root] : []
gem_root = Pathname(__dir__).parent.parent
candidate_dirs = [gem_root, *plugin_roots]
                 .map { |root| Pathname(root.to_s).join("specifications") }
                 .uniq
                 .select(&:directory?)

searched_dirs = Gem::Specification.dirs.map { |dir| Pathname(dir) }
unsearched_dirs = candidate_dirs - searched_dirs

if unsearched_dirs.any?
  Gem::Specification.dirs = (searched_dirs + unsearched_dirs).map { |dir| dir.parent.to_s }
elsif candidate_dirs.any?
  begin
    Gem::Specification.find_by_name("gemvault")
  rescue Gem::LoadError
    # The searched dirs are right but the spec cache predates this install:
    # `bundle plugin install` switches GEM_HOME to the plugin root and caches
    # specs during resolution, before gemvault lands there.
    Gem::Specification.reset
  end
end

# Bundler evaluates this file more than once per process: once when it saves a
# freshly installed plugin, again when the Gemfile asks for the source. Loading
# gemvault twice from two different roots is fatal rather than merely noisy,
# because Gemvault::GemEntry subclasses a fresh Data.define result each time, so
# a second definition raises a superclass mismatch. Resolve and require only on
# the first evaluation. The registration has to repeat on every evaluation --
# Bundler reads the source back out of Plugin::API after each load.
if defined?(Bundler::Plugin::VaultSource)
  Bundler::Plugin::API.source("vault", Bundler::Plugin::VaultSource)
  return
end

# Development: when loaded from within the gemvault source tree, the gemvault
# gem isn't installed, so its lib/ must be on $LOAD_PATH for the require below.
gemvault_lib = Pathname(__dir__).parent.join("lib")
$LOAD_PATH.unshift(gemvault_lib.to_s) if gemvault_lib.directory? && !$LOAD_PATH.include?(gemvault_lib.to_s)

# Making the spec dirs searchable is not enough on its own. Bundler skips
# installing a plugin dependency that is already installed on the ambient
# GEM_PATH, so on any machine with `gem install gemvault` the plugin root holds
# the shim alone. Once the app bundle is populated Bundler restricts GEM_PATH to
# the bundle, the ambient gemvault falls out of scope, and there is no spec dir
# left to find. So locate gemvault's lib directory across every root that could
# hold it and put it on $LOAD_PATH.
#
# Gem.default_path is the load-bearing entry. It is what RubyGems itself knows
# about its own gem roots, so it holds wherever `gem install gemvault` landed
# regardless of what the current, narrowed GEM_PATH says. Reading the roots back
# out of the environment is not enough: rubies installed by rbenv, asdf, chruby,
# Homebrew or a distro export neither GEM_HOME nor GEM_PATH, so on them
# Bundler's stashed environment is empty. It is still worth consulting for the
# rubies that do export a gem root outside RubyGems' defaults, such as RVM and
# the ruby container images.
#
# $LOAD_PATH rather than gem activation is deliberate: vault_source.rb reaches
# the rest of gemvault through require_relative alone, so it needs no dependency
# resolution. Activating the gem would demand command_kit, which only the CLI
# uses and which Bundler leaves out of the plugin root for the same reason.
exported_roots = if defined?(Bundler) && Bundler.respond_to?(:original_env)
                   original = Bundler.original_env
                   [original["GEM_HOME"], *original["GEM_PATH"].to_s.split(File::PATH_SEPARATOR)]
                 else
                   []
                 end

gem_roots = [gem_root, *plugin_roots, *Gem.path, *Gem.default_path, *exported_roots]
            .reject { |root| root.to_s.empty? }
            .map { |root| Pathname(root.to_s) }
            .uniq

vault_source_path = Pathname("bundler/plugin/vault_source.rb")
gemvault_libs = gem_roots
                .flat_map { |root| root.glob("gems/gemvault-*/lib") }
                .select { |lib| lib.join(vault_source_path).file? }

# The shim and gemvault are released together and the gemspec pins an exact
# version, so a matching directory is the right one wherever it lives. Failing
# that -- the shim's directory is not named for its version when it is loaded
# from a source tree, a path: plugin or a git plugin -- prefer the newest
# gemvault found rather than whichever the filesystem happened to list first,
# which is lexical and puts 0.10.0 before 0.9.0. Directories whose suffix is not
# a version are left out of the comparison rather than raising from it.
versioned_libs = gemvault_libs.filter_map { |lib|
  version = lib.parent.basename.to_s.delete_prefix("gemvault-")
  [version, lib] if Gem::Version.correct?(version)
}

shim_version = Pathname(__dir__).basename.to_s.delete_prefix("bundler-source-vault-")
matching_lib = versioned_libs.find { |version, _lib| version == shim_version }
newest_lib = versioned_libs.max_by { |version, _lib| Gem::Version.new(version) }
resolved_lib = (matching_lib || newest_lib)&.last || gemvault_libs.first

# Skipping activation also skips gemvault's runtime dependencies, and the tar
# backend needs one of them: gemvault/manifest.rb requires json, a default gem
# upstream but a separate package on distros. Once Bundler has narrowed
# GEM_PATH to the bundle, RubyGems can no longer satisfy that require and the
# first vault read raises LoadError. So resolve gemvault's declared
# dependencies the same way and put their require paths -- extension
# directories included -- on $LOAD_PATH too. A dependency that cannot be found
# is skipped rather than fatal, which is the whole reason activation is not
# used: it would abort on command_kit, which only the CLI needs.
gemvault_spec = resolved_lib &&
                Gem::Specification.load(
                  resolved_lib.parent.parent.parent
                              .join("specifications", "#{resolved_lib.parent.basename}.gemspec").to_s,
                )

dependency_specs = (gemvault_spec&.runtime_dependencies || []).filter_map { |dependency|
  gem_roots.flat_map { |root| root.glob("specifications/#{dependency.name}-*.gemspec") }
           .filter_map { |spec_file| Gem::Specification.load(spec_file.to_s) }
           .select { |spec| spec.name == dependency.name && dependency.requirement.satisfied_by?(spec.version) }
           .max_by(&:version)
}

[*dependency_specs.flat_map(&:full_require_paths), resolved_lib&.to_s].compact.each do |path|
  $LOAD_PATH.push(path) unless $LOAD_PATH.include?(path)
end

require "bundler/plugin/vault_source"

Bundler::Plugin::API.source("vault", Bundler::Plugin::VaultSource)
