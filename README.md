# Gemvault

A file that behaves like a private gem server.

You can commit it to your repo, drop it on S3, email it, put it on a USB drive, or whatever you feel like doing. Bundler and RubyGems read from it directly.

## Installation

```bash
gem install gemvault
```

## Usage

### Bundler

```ruby
# Gemfile
source "https://rubygems.org"

source "vendor/private.gemv", type: :vault do
  gem "my_private_gem"
end
```

```bash
bundle install
```


### Bundler, for Dependabot and other tools that do not install plugins

Dependabot evaluates a Gemfile without installing Bundler plugins and accepts
only rubygems, git and path sources, so it cannot read `type: :vault`. Name the
vault by a gem source address instead:

```ruby
# Gemfile
source "https://rubygems.org"

source "https://gemvault.invalid/vendor/private.gemv/" do
  gem "my_private_gem"
end
```

The plugin needs **Bundler 4.1.0 or newer**, for both this form and
`type: :vault`, and refuses to install on an older one.

`gemvault.invalid` resolves nowhere and is never contacted. Everything after it
is the vault's path relative to the Gemfile. The plugin publishes the vault as a
local gem index under `.bundle/gemvault/` and mirrors the address to it, so the
lockfile holds an ordinary `GEM` section.

```bash
bundle plugin install bundler-source-vault   # once per project
bundle install
git add -f .bundle/plugin                    # so Dependabot's clone has the plugin
```

- Bundler 4.1.0 is the first with the `after-eval` plugin hook this relies on,
  and the first to write relative paths into a plugin index, which is what
  makes a committed `.bundle/plugin` work in someone else's clone.
- Do not add a `plugin "bundler-source-vault"` line to the Gemfile. Bundler
  would resolve it before the plugin can redirect the address.
- Ignore `.bundle/gemvault/`. It holds one index per vault, rebuilt whenever the
  vault file changes, and the index it replaces is removed. A `bundle` command
  that was already running when the vault changed may lose its index and need
  running again.
- The index moves to your Bundler cache (`~/.bundle/cache/gemvault/`, or
  wherever `BUNDLE_USER_CACHE` points), one directory per project, when the
  project's own directory cannot hold it: its path has a space or a character
  outside ASCII, which a `file://` address cannot carry, or it is read-only.
  When `BUNDLE_APP_CONFIG` points outside the project, as it does in the
  official `ruby` container image, the index is kept there instead of in
  `.bundle/`, in a directory of its own per project.
  `bundle install --verbose` prints where each vault is served from.
- Keep the vault under the Gemfile's directory, and name every part of its
  path so that no `_` sits next to another `_`, a `.` or a `-`
  (`vendor/my_gems.gemv` is fine; `vendor/my__gems.gemv` and `../my_gems.gemv`
  are not). Bundler cannot carry such a path in a mirror setting, and the
  plugin says so instead of installing. A `mirror.all` setting also takes over
  the address, and the plugin reports that too.
- Bundler includes the names of its settings in the User-Agent it sends to
  every gem server the bundle contacts. The mirror is one of them, so those
  servers see the vault's path as written in the Gemfile.
- The mirror is set for the running process only. Nothing is written to the
  project's or your own Bundler config.
- The vault file has to be present wherever the Gemfile is evaluated,
  including at application boot, as it does with `type: :vault`.
- For Dependabot version updates, list the vault's gems under `ignore` in
  `dependabot.yml`. Dependabot asks a gem's source directly for newer versions,
  and the address answers nothing. Security updates need no extra configuration.
- Resolution is slower than with `type: :vault`: a `file://` index has no
  dependency API, so Bundler warns that the Gemfile "contains scoped sources
  that don't implement a dependency API" and fetches the full index of every
  source, rubygems.org included.

### RubyGems CLI

```bash
gem install --source myvault.gemv my_private_gem
gem install --source file:///path/to/myvault.gemv my_private_gem
```

### Creating and managing vaults

```bash
gemvault new myvault                          # creates myvault.gemv
gemvault add myvault.gemv foo.gem bar.gem     # add .gem files
gemvault list myvault.gemv                    # list contents
gemvault remove myvault.gemv foo 1.0.0        # remove a gem
gemvault extract myvault.gemv foo -o vendor/  # extract .gem file to disk
gemvault upgrade myvault.gemv                 # migrate to the current format
```

## Vault format versioning

Every vault records an on-disk **format version** — `1` for the original SQLite format, `2` for a tarball with a JSON manifest, `3` for the current tarball with a plain-text manifest. This version lives inside the file and is **independent of the gemvault gem version**: it changes only when the storage layout changes, so upgrading the gem never invalidates your vaults.

gemvault reads any format up to the one it understands and **refuses a vault written by a newer gemvault** with a clear message (rather than silently misreading it).

Formats `1` (SQLite) and `2` (JSON manifest) are **deprecated and read-only**: you can still list, extract from, and migrate an existing one, but `add`/`remove` are refused and print `gemvault upgrade`. Opening one shows a one-time deprecation notice (silence it with `GEMVAULT_SILENCE_DEPRECATIONS=1`). SQLite support will be removed in a future release (0.3–0.5). To migrate a vault to the current format:

```bash
gemvault upgrade myvault.gemv              # e.g. SQLite (v1) or JSON manifest (v2) -> current (v3)
gemvault upgrade myvault.gemv --dry-run    # show the plan, change nothing
gemvault upgrade myvault.gemv --no-backup  # skip the default myvault.gemv.bak copy
```

`upgrade` preserves every gem, writes `myvault.gemv.bak` by default, and is a no-op on an already-current vault. Timestamps survive a v1 upgrade; a v2 vault's are restamped, because its stored times live in the JSON index this gemvault deliberately no longer reads — the gems themselves are read straight out of the tarball.

## How It Works

The gemv file is a tarball containing your .gem files and a plain-text manifest. It has no dependencies other than the tar utilities that rubygems provides.

```console
$ tar -xOf myvault.gemv manifest
gemvault 3
created 2026-08-12T18:23:32Z

rails 7.1.3 ruby 2026-08-12T18:23:32Z 9f2c...  0
```

One header, then one line per gem: name, version, platform, when it was stored, its SHA256, and whether it is encrypted. Every field is drawn from an alphabet without whitespace, so reading the index needs no parser beyond `split` — and `grep`, `awk` and `cut` work on it directly.

When Bundler sees `type: :vault` in your Gemfile, it auto-installs the `bundler-source-vault` plugin from rubygems.org. The plugin implements the `Bundler::Plugin::API::Source` interface — it reads gemspecs from the vault, participates in dependency resolution, then extracts and installs gems from the vault's blob storage.

The RubyGems plugin works similarly: `gem install --source vault.gemv` loads specs and extracts gems on demand.

## Recovering from broken bundler plugin state: `gemvault doctor`

`gemvault doctor` repairs two kinds of wreckage.

**A ghost installation.** If a gem home holds a `specifications/bundler-source-vault-<version>.gemspec` whose `gems/` directory is gone (an interrupted `gem uninstall`, a hand-cleaned gem home), Bundler older than 4.1.0 trusted the leftover record and every install died with:

```
Installing bundler-source-vault 0.2.4
Failed to install plugin `bundler-source-vault`, due to Bundler::Plugin::MalformattedPlugin (plugins.rb was not found in the plugin.)
```

Bundler 4.1.0 installs past such a record, but it stays in the machine's gem home. `doctor` finds such records across your gem roots, removes them (reporting each), and reinstalls the plugin.

**A broken plugin path.** If you installed `bundler-source-vault` from a local path (e.g. `plugin "bundler-source-vault", path: "/path/to/gemvault"` in a Gemfile), bundler records that absolute path in its plugin index. Moving, renaming, or deleting the source directory afterwards invalidates the stored path, and the next `bundle install` prints:

```
The following plugin paths don't exist: /path/to/gemvault/shim/.
Continuing without installing plugin bundler-source-vault.
```

Once the plugin skips loading, bundler crashes with `NoMethodError: undefined method 'new' for nil` on any Gemfile that uses `type: :vault`. This is a bundler limitation — the plugin index isn't revalidated against the filesystem, and there's no plugin-side hook that fires early enough to preempt it.

To recover, update the Gemfile to point at the new path and run:

```bash
gemvault doctor
```

`doctor` removes any ghost installation records, clears the broken entry from bundler's plugin index (`bundle plugin uninstall bundler-source-vault`) and then, when a Gemfile exists, re-runs `bundle install`, which reinstalls the plugin against whatever the current Gemfile declares. Run it from your project directory. If a ghost record sits in a root-owned gem home, doctor says so on one line — re-run it with permissions for that gem home (e.g. `sudo gemvault doctor`).

A project whose Gemfile is inline (`require "bundler/inline"`) works too. Such a script keeps its plugin index in `<project>/.bundle/plugin`, a root bundler only consults while the script runs; doctor reaches it the same way the script did. With no Gemfile on disk there is nothing to reinstall from, so doctor clears the entry, says so, and exits 0 — the inline gemfile reinstalls the plugin the next time the script runs. Run outside any project, doctor works against bundler's global index and points you back at the project directory for the reinstall.

The repair is transactional. `bundle install` does more than reinstall the plugin, and that extra work can fail on its own — a Ruby version pin, an unresolvable gem. When it does, doctor says so in one line and exits 1; and if the failure struck before the plugin was reinstalled, doctor puts the plugin index back the way it found it. A failed run never leaves the machine with less than it started with — fix the install error and re-run.

The published `bundler-source-vault` gem installed from rubygems.org is immune to this: it lives in a bundler-managed directory that does not move.

## Development

```bash
git clone https://github.com/gillisd/gemvault
cd gemvault
bin/setup
bundle exec rake test         # unit tests
bundle exec rake spec         # specs + container integration tests
bundle exec rake              # all of the above + rubocop
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
