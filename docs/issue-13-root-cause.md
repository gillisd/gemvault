# Issue #13 — `cannot load such file -- bundler/plugin/vault_source`

Line references are to the vendored RubyGems/Bundler checkout in
`references/rubygems` (`bundler-v4.0.0-1207-gf912ac9b0b`).

## Symptom

```
❯ bundle install
Fetching gem metadata from https://rubygems.org/.......
Resolving dependencies...
Installing bundler-source-vault 0.2.0

[!] There was an error parsing `Gemfile`: cannot load such file -- bundler/plugin/vault_source. Bundler cannot continue.

 #  from /Users/davidgillis/repos/reversal-store/Gemfile:19
 >  source "vendor/vendored.gemv", type: :vault do
```

Reported as permanent. `gemvault doctor`, `rm -rf .bundle/plugin`, `rm -f
Gemfile.lock`, and the two combined all left it unchanged.

## Reproduction

The reporter's `.bundle` tarball showed a plugin root holding the shim and
nothing else:

```
.bundle/plugin/cache/bundler-source-vault-0.2.0.gem
.bundle/plugin/gems/bundler-source-vault-0.2.0/plugins.rb
.bundle/plugin/specifications/bundler-source-vault-0.2.0.gemspec
.bundle/plugin/index
```

No `gemvault` anywhere. Reproduced exactly with: gemvault installed on the
ambient `GEM_PATH`, the shim not installed, a project-local `.bundle` with a
configured bundle path, and `bundle install` run **twice**.

## Root cause

Three independent mechanisms compose. Each is fine alone.

### 1. Bundler never puts gemvault in the plugin root

`Source::Rubygems#install` (`lib/bundler/source/rubygems.rb:206`) short-circuits:

```ruby
if (spec.default_gem? && !cached_built_in_gem(...)) || (installed?(spec) && !options[:force])
  print_using_message "Using #{version_message(spec, options[:previous_spec])}"
  return nil
end
```

`installed?` (`:484`) consults `installed_specs`. On any machine where
`gem install gemvault` has run — that is, anyone who uses the CLI — the ambient
copy satisfies it. Bundler prints "Using gemvault" and the plugin root receives
the shim alone. Nothing is downloaded, so the plugin root's `cache/` has no
gemvault either, which is exactly what the reporter's tarball showed.

### 2. The ambient copy disappears precisely when it is needed

`Plugin::Installer#install_all_sources` calls
`Bundler.configure_gem_home_and_path(Plugin.root)`
(`lib/bundler/plugin/installer.rb:100`), and `configure_gem_path`
(`lib/bundler.rb:661`) does:

```ruby
unless use_system_gems?
  Bundler::SharedHelpers.set_env "GEM_PATH", ""
end
```

With a configured bundle path, `use_system_gems?` is false, so `GEM_PATH`
becomes empty and `Gem.path` collapses to the bundle. The copy that made step 1
"safe" is now out of scope.

This is why the failure is **permanent and why it starts on the second run**.
The first `bundle install` succeeds because the ambient gemvault is still
visible. It populates the bundle path. From then on every `bundle install`
narrows `GEM_PATH`, and every recovery step the reporter tried rebuilds the same
incomplete plugin root.

### 3. Locating gemvault is not sufficient — activation cannot survive here

The obvious repair — find gemvault and load it — has a trap. Loading it via
`$LOAD_PATH` skips activation, and therefore skips its dependencies. gemvault
reads a vault manifest through `json` (`lib/gemvault/manifest.rb:1`), so the
plugin dies later, at first vault read, instead of at load.

Activating instead does not work, for two separate reasons:

- **The path would be stripped one line before it is used.** `Runtime#setup`
  (`lib/bundler/runtime.rb:12-38`) runs `clean_load_path` at line 16 and
  `@definition.specs_for(groups)` at line 18 — and resolution is what asks the
  vault source for specs. `clean_load_path`
  (`lib/bundler/shared_helpers.rb:371-380`) rejects a `$LOAD_PATH` entry only
  when `loaded_gem_paths.delete(p)` is truthy, and `loaded_gem_paths`
  (`lib/bundler/rubygems_integration.rb:132-135`) is built from
  `Gem.loaded_specs` — i.e. **activated gems**. Activating is what would put the
  path on the chopping block. A directory pushed without activation is absent
  from that list, so `delete` returns nil and the entry survives.

- **`Gem::Specification` cannot see outside the bundle.** `stub_rubygems`
  (`lib/bundler/rubygems_integration.rb:336-340`) sets
  `Gem::Specification.all = specs` and reapplies it through `Gem.post_reset`, so
  under `bundle exec` `find_by_name` cannot find a gem installed outside the
  bundle, and `Gem::Specification.reset` will not restore it.

## Why the test suite could not catch any of this

The integration container was the official `ruby` image. It differs from a
machine anyone develops on in four ways, and each one hid one layer:

| Image behaviour | What it hid |
|---|---|
| `gemvault` **and** `bundler-source-vault` installed system-wide | `require "bundler/plugin/vault_source"` resolved from `/usr/local/bundle` no matter what the plugin root held |
| `BUNDLE_APP_CONFIG=/usr/local/bundle` | `Bundler::Plugin.root` was never project-local, so no spec touched a real `.bundle/plugin` |
| `GEM_HOME` exported | a first repair that read gem roots out of the environment appeared to work |
| `json` present as a default gem | the undeclared dependency was invisible |

The first repair for this issue reconstructed gem roots from
`Bundler.original_env`, which is a snapshot of environment variables.
`GEM_HOME`/`GEM_PATH` are only present there if something exported them —
rbenv, asdf, chruby, Homebrew and distro rubies export neither. The reporter is
on rbenv (`issues.rec`: `/Users/davidgillis/.rbenv/versions/4.0.1/`,
`rbenv 1.3.2`), so that repair passed its specs in Docker and still failed on
their machine.

The suite now runs on `fedora:44` with a distro ruby: gems in RubyGems' own
default dirs, nothing exported, bundler a regular gem. Moving to it immediately
surfaced two further real defects — the undeclared `json` dependency, and the
`json/ext/parser` extension path.

## The fix

`shim/gemvault_load_path.rb` locates gemvault and its declared runtime
dependencies across every root that could hold them, and pushes their require
paths onto `$LOAD_PATH`.

- **`Gem.default_path` is the load-bearing root.** It is what RubyGems knows
  about its own gem roots, independent of the narrowing in step 2, so it covers
  rubies that export nothing. `Bundler.original_env` is still consulted, for the
  rubies that do export a root outside those defaults, such as RVM.
- **`$LOAD_PATH`, not activation**, for the reasons in step 3.
- **Dependencies resolved by hand**, using `full_require_paths`
  (`lib/rubygems/basic_specification.rb:172-183`), which appends `extension_dir`
  when `have_extensions?` — without it `json/ext/parser` is unfindable, since
  json's compiled half lives outside its gem directory.
- **A dependency that cannot be found is skipped rather than fatal.** That is
  the one thing activation could not do: it would abort on `command_kit`, which
  only the CLI needs.
- **`json` is now a declared runtime dependency**, so `gemvault new` works on a
  stock distro ruby.

## Coverage

`spec/support/vault_sourced_gemfile_examples.rb` applies "a complete bundle" to
a vault-sourced Gemfile and then re-applies it after each user action: deleting
`Gemfile.lock`, deleting `.bundle`, deleting both, removing the vaulted gem,
adding a gem from rubygems, adding another from the same vault, and adding one
from a second vault. `spec/integration/vaulted_project_spec.rb` runs that whole
group under four bundler configurations — stock, an install path chosen, that
path undone, and the project's gems cached — and
`spec/integration/no_ambient_gemvault_spec.rb` covers the machine that has no
gemvault of its own, where the plugin root has to carry the whole dependency
set.
