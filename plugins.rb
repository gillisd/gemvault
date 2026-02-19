# frozen_string_literal: true

# Bundler installs plugin dependencies (e.g. sqlite3) into Plugin.root but
# does not add their load paths before loading plugins.rb. This is a known
# Bundler limitation — see the "Currently not done to avoid conflicts" comment
# in bundler/plugin.rb#load_plugin.
#
# Work around by registering Plugin.root as a gem search path so dependencies
# installed there are activatable via `require`.
if defined?(Bundler::Plugin)
  plugin_root = Bundler::Plugin.root.to_s
  spec_dir = File.join(plugin_root, "specifications")
  if File.directory?(spec_dir) && !Gem::Specification.dirs.include?(spec_dir)
    Gem::Specification.dirs = Gem.path + [plugin_root]
  end
end

require_relative "lib/bundler/plugin/vault_source"

Bundler::Plugin::API.source("vault", Bundler::Plugin::VaultSource)
