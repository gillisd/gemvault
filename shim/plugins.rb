# An addressed vault is redirected from Bundler's after-eval hook, which
# Bundler gained in 4.1.0. An older Bundler would leave the address unredirected
# and fail as an unreachable host, so it is refused here, by name.
unless Bundler::Plugin::Events.defined_event?("after-eval")
  raise Bundler::PluginError, "bundler-source-vault needs Bundler 4.1.0 or newer; this is Bundler #{Bundler::VERSION}"
end

require_relative "gemvault_load_path"

# Runs on every evaluation. Bundler discards the registration while configuring
# the bundle, so it cannot sit behind the guard below.
BundlerSourceVault::GemvaultLoadPath.register_spec_dirs

# Bundler evaluates this file more than once per process: once when it saves a
# freshly installed plugin, again when the Gemfile asks for the source. Loading
# gemvault twice from two different roots is fatal rather than merely noisy,
# because Gemvault::GemEntry subclasses a fresh Data.define result each time, so
# a second definition raises a superclass mismatch. Resolve and require only on
# the first evaluation. The registration above and those below still repeat --
# Bundler reads the source back out of Plugin::API after each load.
unless defined?(Bundler::Plugin::VaultSource)
  source_tree_lib = BundlerSourceVault::GemvaultLoadPath.source_tree_lib
  $LOAD_PATH.unshift(source_tree_lib.to_s) if source_tree_lib && !$LOAD_PATH.include?(source_tree_lib.to_s)

  BundlerSourceVault::GemvaultLoadPath.apply

  require "bundler/plugin/vault_source"
  require "bundler/plugin/vault_redirection"
end

Bundler::Plugin::API.source("vault", Bundler::Plugin::VaultSource)

# A Gemfile may instead address a vault as an ordinary gem source, so that it
# and its lockfile carry no plugin source. Bundler loads this file for the
# after-eval hook from the plugin index alone, which is what lets a tool that
# never installs plugins still resolve from a vault committed beside the plugin.
Bundler::Plugin::API.hook("after-eval") do |definition|
  Bundler::Plugin::VaultRedirection.new(definition).apply
end
