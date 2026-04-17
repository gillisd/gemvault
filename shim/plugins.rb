# Bundler installs plugin dependencies (e.g. sqlite3) into Plugin.root but
# does not add their load paths before loading plugins.rb. This is a known
# Bundler limitation see the"Currently not done to avoid conflicts" comment
# in bundler/plugin.rb#load_plugin.
#
# Work around by registering Plugin.root as a gem search path so dependencies
# installed there are activatable via `require`.
# Development: when loaded from within the gemvault source tree, the gemvault
# gem isn't installed so its lib/ must be on $LOAD_PATH for the require below.
gemvault_lib = File.expand_path("../lib", __dir__)
$LOAD_PATH.unshift(gemvault_lib) unless $LOAD_PATH.include?(gemvault_lib)

if defined?(Bundler::Plugin)
  plugin_root = Bundler::Plugin.root.to_s
  spec_dir = File.join(plugin_root, "specifications")
  if File.directory?(spec_dir) && !Gem::Specification.dirs.include?(spec_dir)
    Gem::Specification.dirs = Gem.path + [plugin_root]
  end
end

require "bundler/plugin/vault_source"

Bundler::Plugin::API.source("vault", Bundler::Plugin::VaultSource)
