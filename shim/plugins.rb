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

require "bundler/plugin/vault_source"

Bundler::Plugin::API.source("vault", Bundler::Plugin::VaultSource)
