# Issue #31 demonstrations

Two self-contained host reproductions of issue #31 ("gems installed with
`gem install --source myvault.gemv` no longer work"), written while
diagnosing the report and adding the failing spec at
`spec/integration/vault_installed_executable_spec.rb`. They exist because
this machine had no podman to run the integration suite; each renders the
helper files it needs from `spec/support/` at run time, works under
`tmp/`, and removes its work directory on exit (`KEEP=1` preserves it).

## The mechanism they demonstrate

The crash is not a gemvault code regression — no gemvault code runs before
it. Two bundler behaviors compose into the wreck:

1. When `bundle install` resolves the Gemfile-inferred plugin on a machine
   carrying an ambient `gem install`'d copy of it, the installer's
   `installed?` shortcut skips populating `.bundle/plugin/gems/` and the
   index records the **ambient gem home's absolute paths** as the plugin's
   `load_paths`.
2. Since bundler 2.6.0 (rubygems/rubygems commit `0c6ad3ecbb`, still on
   master), `Plugin.load_plugin` silently skips a plugin whose recorded
   load paths no longer exist, after a warning that `bundler/setup`'s
   `Bundler.ui.silence` swallows. `Plugin.source("vault")` then returns
   nil and `Bundler::SourceList#add_plugin_source` crashes with
   `undefined method 'new' for nil` — the reported error, with no remedy
   named.

Any ordinary decay event detonates state laid down months earlier: `gem
cleanup` after a gemvault upgrade (why the report blames 0.2.7), a ruby
version switch, `gem uninstall bundler-source-vault`.

## micro.sh

The mechanism in isolation — a throwaway `bundler-source-fake` plugin, no
gemvault involved. Runs with whatever ruby is on PATH (its bundler must be
>= 2.6.0). Shows the poisoned index, the empty plugin root, a working
`bundler/setup` while the ambient copy is intact, and the crash after
`gem uninstall`. Serves its gem index on port 8809. Verified 2026-08-18
against ruby 3.4.7 / bundler 2.6.9.

## demo.sh

The report end to end with the tree's own gems: gemvault + the shim built
from the working tree, bundler 4.0.17 (the version `Dockerfile.test`
pins), a real `.gemv` vault, and a `vault_tool` gem whose executable
requires `bundler/setup` — the `rstore` of the report. The control run
prints `vault_tool ready` ("this path used to work"); after the ambient
shim leaves the gem home, the identical `gem install --source` +
`vault_tool` sequence dies at `source_list.rb:59` exactly as reported.
Needs a ruby satisfying the gemspec's `required_ruby_version` (pass
`DEMO_RUBY_PREFIX`, default `rbenv prefix 3.4.9`) and network access for
bundler 4.0.17 and command_kit. Serves its gem index on port 8808.
Verified 2026-08-18 against ruby 3.4.9 / bundler 4.0.17.

Both scripts exit 0 when the crash reproduces and 1 if the decayed machine
unexpectedly works — so a future fix flips them, same as the failing spec.
