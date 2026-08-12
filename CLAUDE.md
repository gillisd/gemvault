# CLAUDE.md — Gemvault

## Rubocop

Do NOT modify `.rubocop.yml` or use inline `# rubocop:disable` tags without explicit permission. Fix the code to satisfy the cop instead.

## General rules

1. Specs always come first. Every plan should start with the skeleton of the BDD specs being added, changed or removed. Skeleton means the empty RSpec language, without implementation.
2. Specs should never have comments. Any urge to put a comment in a spec means that comment should probably be its own spec
3. DO NOT edit .rubocop.yml or add inline rubocop exemptions without explicit permission
4. DO NOT edit .rubycritic.yml or add inline rubycritic exemptions without explicit permission
5. DO NOT run any git command that will rewrite history without explicit permission
6. PREFER method & class extraction over comments
7. Making new files, classes, modules, and methods IS NOT overengineering
8. BEFORE writing code, identify which domain concept owns the behavior. Each class and module should have a single responsibility. If the new behavior doesn't fit an existing class's responsibility, create a new one — don't expand the scope of what's already there.
9. DO NOT name classes with suffixes like "-er" or "-or" unless using a canonical pattern name (e.g., Parser, Router, Controller)
10. ALWAYS write specs first. The workflow is: identify the domain concept (rule 5), write specs describing its behavior, then implement. No implementation without a failing spec.
11. Integration specs are the first line of defense for CLI-tool bugs. For any bug reported from using the CLI tool (not the gemvault lib / Ruby API), the FIRST spec you write is an integration spec that reproduces the user's exact invocation — real subprocess, real vault, real exit code. Stub-heavy unit specs are complementary, not sufficient: they prove internal logic produces the expected value assuming surrounding wiring works, but a user's bug report is evidence the wiring didn't work.
12. If an integration spec is not catching a reported CLI-tool bug, one of two things is true, and the fix starts by diagnosing which: (a) existing integration specs are not specific enough — extend them to cover the exact scenario before touching production code; or (b) the scenario is not spec'd at all, which means the work is not a bug fix but a new feature — write integration specs for the contract first (per rule 1), then implement.
13. NEVER write to /tmp. Use /workspace/tmp

## Additional rules

1. NEVER use Ruby's `sleep` method
2. NEVER create any class ending in "er" or "or"

## Project Overview

Multi-gem portable archives. A single `.gemv` file is a tarball holding multiple `.gem` files plus a `manifest.json` index; legacy SQLite vaults are read-only.

Two gems, one repo:

- **`gemvault`** — the real gem. All code, CLI, RubyGems plugin. Published to rubygems.org.
- **`bundler-source-vault`** — thin shim in `shim/`. Depends on `gemvault`, has a `plugins.rb` that registers the Bundler source. Published to rubygems.org so Bundler's `type: :vault` auto-discovery works. Users never interact with this name directly.

### User experience

```ruby
# Gemfile — once both gems are published to rubygems.org, no plugin line needed:
source "myvault.gemv", type: :vault do
  gem "foo"
end

# Until then, point Bundler at the local source:
plugin "bundler-source-vault", path: "/path/to/gemvault"
```

Bundler auto-infers `bundler-source-vault` → installs it → pulls in `gemvault` as dependency → `plugins.rb` registers the vault source.

Also works as a RubyGems plugin:

```bash
gem install --source myvault.gemv foo
gem install --source file:///path/to/myvault.gemv foo
```

## Architecture

- `gemvault.gemspec` — main gem spec (name: `gemvault`)
- `lib/gemvault/vault.rb` — Vault facade choosing a backend by file format (Tarvault current, legacy Dbvault read-only)
- `lib/gemvault/cli.rb` — CLI dispatcher (new/add/list/remove/extract)
- `lib/gemvault/ghost_specification.rb` — installation records whose gem directory is gone; swept by `gemvault doctor` (issue #23)
- `lib/bundler/plugin/vault_source.rb` — Bundler `Plugin::API::Source` implementation
- `lib/rubygems_plugin.rb` — RubyGems plugin: monkey-patches for `--source myvault.gemv` support
- `lib/rubygems/source/vault.rb` — `Gem::Source::Vault` class (spec loading, download, `file://` URI handling, verbose logging)
- `lib/rubygems/resolver/vault_set.rb` — `Gem::Resolver::VaultSet` for dependency resolution
- `exe/gemvault` — CLI executable
- `shim/bundler-source-vault.gemspec` — thin shim gemspec depending on `gemvault`
- `shim/plugins.rb` — Bundler plugin registration + `Gem::Specification.dirs` workaround
- `plugins.rb` — development-only redirect to `shim/plugins.rb` (not shipped in gems)

## Key Design Decisions

- Tar storage — portable, dependency-free, single file, inspectable with `tar`; legacy SQLite vaults readable via lazily-loaded sqlite3
- Specs extracted from gem blobs at runtime (no separate spec storage)
- Vault opened/closed per operation in the source plugin (no persistent connection)
- `fetch_gemspec_files` checks installed state — Bundler computes `full_gem_path` as `dirname(loaded_from)`, so `loaded_from` must point inside the gem directory
- `bundler-source-vault` name exists because Bundler auto-infers plugin name from `type: :vault` → `bundler-source-vault`
- `file://` URIs stripped to plain paths in `Gem::Source::Vault#initialize`
- Verbose logging via `Gem::UserInteraction#verbose` for `--verbose` support
- `shim/plugins.rb` loads gemvault by putting its `lib` on `$LOAD_PATH`, never by
  activating the gem. Bundler skips installing a plugin dependency already
  present on the ambient GEM_PATH, so the plugin root often lacks gemvault, and
  by load time GEM_PATH is restricted to the plugin root and the app bundle. The
  shim therefore searches every root that can hold gemvault, including the ones
  Bundler masked (`Bundler.original_env` GEM_HOME/GEM_PATH). Activation is
  avoided because it demands gemvault's full runtime dependency set (command_kit),
  which Bundler skips for the same reason — `vault_source.rb` reaches the rest of
  gemvault through `require_relative` alone and needs none of it.

## Testing

```bash
bundle exec rake test
```

Minitest covers the library; RSpec covers the CLI and the containerized
integration suite. `rake` (the default task) runs `test`, `spec`, `rubocop` and `rubycritic`.

```bash
bundle exec rake test            # minitest only
bundle exec rake spec:core       # rspec, no containers
bundle exec rake spec:integration # rspec, containers (builds the image first)
bundle exec rake spec:build      # rebuild the container image
bundle exec rake spec:teardown   # remove it
```

- `test/vault_{lifecycle,mutation,entries,content}_test.rb` — unit tests for the Vault facade
- `test/vault_source_*_test.rb` — unit tests for the Bundler source plugin (metadata, gemspecs, modes, install)
- `test/cli_*_test.rb` — in-process CLI tests (new, add, list, remove, extract, and top-level dispatch; upgrade and doctor are covered by RSpec under `spec/gemvault/cli`)
- `test/rubygems_*_test.rb` — RubyGems source, resolver set, monkey-patches, URI handling
- `spec/integration/` — end-to-end specs, each run inside a podman container
- `spec/support/` — script fragments the integration specs assemble into those containers

Integration specs serve the tree's own gems from a local gem index (`GemIndex`)
to avoid rubygems.org resolution during testing.

Rubycritic scores `lib/`, `spec/support/`, `test/` and `shim/` but not spec
example files: flog taxes each block-nesting level, so idiomatic
describe/context nesting reads as complexity. rubocop-rspec owns spec style.

### Container fidelity — do not undo these

The container has to look like a machine a user actually has. The `ruby` base
image does not, and every way it differs has already hidden a real defect. These
five are load-bearing; reverting any of them silently makes the suite green
against something other than the code under test:

1. **`bundler-source-vault` is NOT installed system-wide in `Dockerfile.test`.**
   An ambient copy satisfies Bundler's plugin resolution without ever populating
   the plugin root. Specs resolve the shim from the local gem index (`GemIndex`)
   so they exercise the tree's shim. `gemvault` IS installed system-wide on
   purpose — that is a real user's machine and the trigger for issue #13.
2. **`BUNDLE_APP_CONFIG` is not set in the container.** The `ruby` image sets it
   to `/usr/local/bundle`, which moves `Bundler::Plugin.root` out of the project
   so no spec ever touches a project-local `.bundle/plugin`. Fedora sets it
   nowhere; do not add it, and do not adopt a base image that does.
3. **`GEM_HOME` and `GEM_PATH` are not exported in the container, and nothing
   pins them.** Gems land in RubyGems' own default dirs. The `ruby` image
   exports `GEM_HOME`; rubies from rbenv, asdf, chruby, Homebrew and distros
   export nothing. Anything that reads gem roots back out of the environment
   finds them on the image and finds nothing on a user's machine — that is what
   made the first fix for issue #13 pass its specs while still failing for the
   reporter. Neither `Dockerfile.test` nor `ContainerHelper#podman_run` should
   grow an `ENV`/`-e` for either variable.
4. **Bundler is pinned to the version users run, not the image's default gem.**
   The plugin machinery under test is Bundler's own, so a stale default silently
   tests different code.
5. **dnf runs with stock settings — weak dependencies included.** On a real
   Fedora machine `dnf install ruby` pulls the unbundled default-gem RPMs
   (`rubygem-json`, `rubygem-psych`, …) through the ruby package's Recommends.
   `--setopt=install_weak_deps=False` builds a ruby no user has — one where
   `require "json"` raises — and that faulty install once failed every CLI
   scenario in the suite.

Fidelity is a property of the image, not of a script fragment: integration specs
run only commands a user would actually type.

If a spec fails only after removing a system-installed gem or an exported
variable, the spec was passing for the wrong reason — fix the spec, not the
container.

## Dependencies

- `bundler` — NOT a dependency; the plugin always runs inside an existing Bundler process, and declaring it breaks gem activation under `bundle exec`'s restricted GEM_PATH
- `command_kit` (~> 0.6) — runtime (CLI)
- `json` — NOT a dependency and never loaded at runtime. `Gemvault::Json` reads and writes the manifest itself: on rubies that resolve `require "json"` through gem activation, a require inside a Bundler-managed process activates the newest installed copy, and a project locking an older one dies in `check_for_activated_spec!` (issue #25). Specs use the real gem to cross-check the codec's output; that is the only place it may be required.
- `sqlite3` (~> 2.0) — NOT a runtime dependency; loaded lazily only to read a legacy SQLite (Dbvault) vault. Declared in the Gemfile for development/test.
- `minitest`, `rspec`, `rake` — development
