# Bundler installs plugin dependencies (here: gemvault) alongside the plugin
# but does not put them on the load path before loading plugins.rb -- see the
# "Currently not done to avoid conflicts" comment in bundler/plugin.rb. The
# require below must resolve gemvault through RubyGems itself, so every gem
# root that may hold gemvault has to be visible to Gem::Specification first.
#
# Development: when loaded from within the gemvault source tree, the gemvault
# gem isn't installed, so its lib/ must be on $LOAD_PATH for the require below.
gemvault_lib = Pathname(__dir__).parent.join("lib")
$LOAD_PATH.unshift(gemvault_lib.to_s) if gemvault_lib.directory? && !$LOAD_PATH.include?(gemvault_lib.to_s)

# Installed, this file lives at <gem root>/gems/bundler-source-vault-<v>/, and
# gemvault sits in the same root: Bundler's local or global plugin root, or a
# plain GEM_HOME when installed with `gem install`. Bundler's plugin roots are
# also candidates because `Bundler::Plugin.root` is the project-local root even
# when the plugin actually loads from the global one.
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

# Making the spec dirs searchable is not enough on its own. Bundler skips
# installing a plugin dependency that is already installed on the ambient
# GEM_PATH, so on any machine with `gem install gemvault` the plugin root holds
# the shim alone. Once the app bundle is populated Bundler restricts GEM_PATH to
# the bundle, the ambient gemvault falls out of scope, and there is no spec dir
# left to find. So locate gemvault's lib directory across every root that could
# hold it -- including the ones Bundler masked -- and put it on $LOAD_PATH.
#
# $LOAD_PATH rather than gem activation is deliberate: vault_source.rb reaches
# the rest of gemvault through require_relative alone, so it needs no dependency
# resolution. Activating the gem would demand command_kit, which only the CLI
# uses and which Bundler leaves out of the plugin root for the same reason.
masked_roots = if defined?(Bundler) && Bundler.respond_to?(:original_env)
                 original = Bundler.original_env
                 [original["GEM_HOME"], *original["GEM_PATH"].to_s.split(File::PATH_SEPARATOR)]
               else
                 []
               end

vault_source_path = Pathname("bundler/plugin/vault_source.rb")
gemvault_libs = [gem_root, *plugin_roots, *Gem.path, *masked_roots]
                .reject { |root| root.to_s.empty? }
                .flat_map { |root| Pathname(root.to_s).glob("gems/gemvault-*/lib") }
                .select { |lib| lib.join(vault_source_path).file? }

# The shim and gemvault are released together and the gemspec pins an exact
# version, so a matching directory is the right one wherever it lives.
shim_version = Pathname(__dir__).basename.to_s.delete_prefix("bundler-source-vault-")
matching_lib = gemvault_libs.find { |lib| lib.parent.basename.to_s == "gemvault-#{shim_version}" }
resolved_lib = matching_lib || gemvault_libs.first
$LOAD_PATH.push(resolved_lib.to_s) if resolved_lib && !$LOAD_PATH.include?(resolved_lib.to_s)

require "bundler/plugin/vault_source"

Bundler::Plugin::API.source("vault", Bundler::Plugin::VaultSource)
