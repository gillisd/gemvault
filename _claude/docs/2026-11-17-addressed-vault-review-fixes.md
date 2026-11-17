# Addressed-Vault Review Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix every finding from the five-reviewer pass on gillisd/gemvault#31 so the PR is safe to merge.

**Architecture:** A new `Gemvault::Shelf` owns everything about the directory an index lives in: its naming, whether a `file://` address can carry it, whether it can be written, and the locked, atomic "stock" operation that publishes into a partial directory and renames it into place. `VaultPublication` shrinks to "stat the vault, ask the shelf, spawn the child, report why it failed". `VaultRedirection` chooses a usable shelf, confirms Bundler actually took the mirror, and translates errors.

**Tech Stack:** Ruby 4.0.9, Bundler 4.0.23 (suite) and 4.1.0 (addressed scenarios), RSpec, podman container specs, RuboCop, RubyCritic.

**Spec:** The review findings, summarised in "Findings covered" below. PR: https://github.com/gillisd/gemvault/pull/31. Project rules: `CLAUDE.md` at the repo root (read it first).

## Global Constraints

- Work on the `dependabot-source-address` branch. New commits only: no amend, rebase, reset or force-push. Push after the last task, not before.
- Do not merge the PR, do not release, do not change the version.
- Spec commit before the code commit it covers. One logical change per commit.
- Code that loads inside the Bundler process (`source_address.rb`, `shelf.rb` at load, `static_index.rb` up to `publish`, `vault_publication.rb`, `vault_redirection.rb`) may `require` only `rubygems` and RubyGems' vendored URI. No default gem: no `fileutils`, `digest`, `pathname`, `zlib`, `open3`, `tmpdir`. A method that only the child process calls may `require "fileutils"` lazily inside the method.
- No comments in spec files. Example descriptions hold no commas. Every `rescue`/`ensure` in `lib/` sits in an explicit `begin ... end`.
- No class names ending in "er"/"or" (`Error` classes excepted, as the repo already does). No `sleep`. Never write to `/tmp`; scratch goes in `/workspace/tmp`.
- No edits to `.rubocop.yml` / `.rubycritic.yml`, no inline cop disables.
- Commands:
  - specs: `bundle exec rspec <paths>`
  - lint: `bundle exec rubocop`
  - everything: `bundle exec rake spec:build` then `bundle exec rake` (about 7 minutes; rebuild the image first or container specs run a stale gem)
- Anything that spawns processes runs under a resource cap, for example `systemd-run --user --scope -q -p TasksMax=500 -p MemoryMax=3G timeout 1500 ...`.

## Findings covered

| # | Finding | Task |
|---|---|---|
| 1 | Vault path with `__`, `_.` (and similar) is never mirrored | 5 |
| 2 | Half-written index trusted forever | 1, 2 |
| 3 | "Activates no gems" spec cannot fail under `bundle exec` | 3 |
| 4 | Cleanup globs an unescaped path and deletes any shelf child | 1 |
| 5 | Concurrent publishers race | 1 |
| 6 | Shelves collide when `BUNDLE_APP_CONFIG` is global | 5 |
| 7 | Publishing errors lose their cause; raw `Errno` escapes | 3, 5 |
| 8 | Plugin installed before a Bundler upgrade stays dead | 7 |
| 9 | Address can point outside the project (`//abs/path`) | 4 |
| 10 | Integration gaps: second source, nested vault, relocated plugin, changed vault | 6 |
| 11 | `latest_specs` lists every version | 2 |
| 12 | Silent fallback; read-only project not handled | 5 |
| 13 | Wrong or stale comments and docs; User-Agent disclosure | 8 |
| 14 | Spec weaknesses (negative address cases, stamp components, weak assertions) | 3, 4, 6 |

## Review Focus

1. Two `bundle` processes publish the same changed vault at once: exactly one publish happens and neither reads a half-written index. Test in Task 1.
2. The publishing process is killed midway: the next run republishes instead of trusting the leftovers. Test in Task 1.
3. A project directory whose name contains `*`: cleanup removes nothing outside its own shelf. Test in Task 1.
4. A read-only project checkout (container image, CI): the index goes to the user cache instead of failing. Test in Task 5.
5. A vault named `my__gems.gemv`: a clear error naming the vault, not "could not reach host". Test in Task 5.

Accepted and documented, not fixed: a `bundle` run that started before the vault changed can lose its index to a later run's cleanup and must be rerun (Task 8 adds the README line).

---

### Task 1: `Gemvault::Shelf`

**Files:**
- Create: `lib/gemvault/shelf.rb`, `spec/gemvault/shelf_spec.rb`
- Modify: `lib/gemvault/static_index.rb` (remove `addressable?`), `spec/gemvault/static_index_spec.rb` (move the `#addressable?` examples to the shelf spec)

**Interfaces:**
- Consumes: `Gemvault::StaticIndex.new(directory)`, `#published?`, `#directory`.
- Produces:
  - `Gemvault::Shelf.new(directory)` (String or Pathname; stored as String), `#directory -> String`, `#to_s -> String` (the directory).
  - `Gemvault::Shelf::STAMP = /\A\d+-\d+-\d+\z/`
  - `#index_for(stamp) -> StaticIndex` at `<directory>/<stamp>`; raises `ArgumentError` unless `stamp` matches `STAMP`.
  - `#addressable? -> bool`: `"file://#{directory}/"` parses with `Gem::URI` and its path equals `"#{directory}/"` (the logic now in `StaticIndex#addressable?`, moved verbatim).
  - `#writable? -> bool`: the nearest existing ancestor of `directory` (or `directory` itself) is a writable directory.
  - `#usable? -> bool`: `addressable? && writable?`.
  - `#stock(stamp) { |index| ... } -> StaticIndex`: the published index for `stamp`. Child-process only; may lazily `require "fileutils"`.

`stock` algorithm (the tests do not fully determine it):

```ruby
# 1. mkdir_p directory; open "<directory>/.lock" (RDWR|CREAT) and flock(LOCK_EX) for the rest
# 2. final = index_for(stamp); return final if final.published?
# 3. rm_rf "<directory>/<stamp>.partial"; yield StaticIndex.new(that path)
# 4. rm_rf final.directory; File.rename(partial, final.directory)
# 5. every Dir.children(directory) entry matching /\A\d+-\d+-\d+(\.partial)?\z/ other than stamp:
#    FileUtils.rm_r it; on SystemCallError, warn "gemvault: could not remove superseded index <path>: <message>" and continue
# 6. return final
```

- [ ] **Step 1: Write the failing spec** `spec/gemvault/shelf_spec.rb` (uses `GemFixtures`; `let(:directory) { gem_dir / "shelf" }`; a helper `def publish_into(index) = open_vault { |vault| index.publish(vault) }` after `current_tarvault`):

  - `#addressable?`: the five examples moved from `static_index_spec.rb` (plain directory true, `vendor%2Ftest.gemv` true, `My Projects` false, `josé` false, `app#1` false).
  - `#writable?`: true when the directory does not exist under a writable parent; false when the parent is `chmod 0555` (restore mode in `after`).
  - `#index_for`: `index_for("1-2-3").directory == "#{directory}/1-2-3"`; `index_for("../x")` raises `ArgumentError`.
  - `#stock`:
    - "publishes the index for the stamp": `shelf.stock("1-2-3") { publish_into(it) }` is `be_published` and its directory is `<directory>/1-2-3`.
    - "does not publish again once published": second `stock("1-2-3")` with a block that raises does not raise.
    - "republishes over a leftover partial index": pre-create `<directory>/1-2-3.partial/gems/junk.gem`; after `stock`, `<directory>/1-2-3/gems/junk.gem` does not exist and `<directory>/1-2-3.partial` does not exist.
    - "treats a stamp directory without the released listing as unpublished": pre-create `<directory>/1-2-3/gems/` only; the block runs (record a flag).
    - "removes the superseded index": stock `1-2-3` then `4-5-6`; `<directory>/1-2-3` is gone.
    - "keeps entries that are not indexes": pre-create `<directory>/keep.txt`; still there after `stock`.
    - context "when the directory name holds a glob character" (`let(:directory) { gem_dir / "app*" / "shelf" }`): pre-create `gem_dir / "apple" / "shelf" / "9-9-9"`; after `stock("1-2-3")` it still exists.
    - "publishes once when two callers stock the same stamp at once": two `Thread`s each call `Gemvault::Shelf.new(directory).stock("1-2-3") { |index| calls << 1; publish_into(index) }` (use a `Queue` for `calls`); `calls.size == 1`.

- [ ] **Step 2: Run** `bundle exec rspec spec/gemvault/shelf_spec.rb` — Expected: FAIL, `uninitialized constant Gemvault::Shelf`.
- [ ] **Step 3: Commit the spec** — `git add spec/gemvault/shelf_spec.rb spec/gemvault/static_index_spec.rb && git commit -m "Specify the shelf an index is published on"`
- [ ] **Step 4: Implement `lib/gemvault/shelf.rb`** per Interfaces; `require_relative "static_index"` only. Remove `StaticIndex#addressable?`. Class rdoc states: one current index per shelf, published into a partial directory under a lock and renamed into place, and that a `file://` address is read undecoded by RubyGems and Bundler.
- [ ] **Step 5: Run** `bundle exec rspec spec/gemvault/shelf_spec.rb spec/gemvault/static_index_spec.rb` — Expected: PASS. (`vault_redirection_spec` breaks until Task 5; expected.)
- [ ] **Step 6: Commit** — `git add lib/gemvault/shelf.rb lib/gemvault/static_index.rb && git commit -m "Publish an index onto its shelf atomically and under a lock"`

### Task 2: `StaticIndex` listings

**Files:** Modify `lib/gemvault/static_index.rb:56-66`, `spec/gemvault/static_index_spec.rb`

**Interfaces:** Produces: `latest_specs.4.8.gz` holds only the highest released version per `[name, platform]`. No signature changes.

- [ ] **Step 1: Add failing examples:**
  - context "when the vault holds two versions of a gem" (`tarvault_with(build_gem(name: "foo", version: "1.0.0"), build_gem(name: "foo", version: "2.0.0"))`): `listed("latest_specs.4.8.gz") == [["foo", Gem::Version.new("2.0.0"), "ruby"]]`; `listed("specs.4.8.gz")` contains both.
  - context "when the vault holds a release and a prerelease of a gem": the prerelease appears only in `prerelease_specs`, the release only in `specs` and `latest_specs`.
  - `#published?` "is false when gems are stored but the released listing is missing": publish, delete `directory / "specs.4.8.gz"`, expect `not_to be_published`.
- [ ] **Step 2: Run** `bundle exec rspec spec/gemvault/static_index_spec.rb` — Expected: the two-version example FAILS (both versions listed as latest).
- [ ] **Step 3: Commit the spec** — `git commit -m "Specify that the latest listing holds one version per gem"`
- [ ] **Step 4: Implement:** in `publish`, pass `list(LATEST, ...)` the result of grouping `released` by `[name, platform.to_s]` and taking `max_by(&:version)` of each group. Update the class comment at lines 12-15 so it no longer mentions an address check.
- [ ] **Step 5: Run** the same spec — Expected: PASS. **Commit** — `git commit -m "List only the newest release of each gem as latest"`

### Task 3: `VaultPublication` reports causes and uses the shelf

**Files:**
- Modify: `lib/gemvault/vault_publication.rb`, `lib/gemvault/publish_static_index.rb`, `spec/gemvault/vault_publication_spec.rb`

**Interfaces:**
- Consumes: `Shelf#index_for`, `Shelf#stock`, `Shelf#directory` (Task 1).
- Produces:
  - `Gemvault::VaultPublication.new(vault_path, shelf:)` where `shelf` is a `Gemvault::Shelf`.
  - `#publish -> StaticIndex`, raising `VaultPublication::Error` for every failure, never a raw `SystemCallError`.
  - Child invocation: `ruby publish_static_index.rb VAULT SHELF_DIRECTORY STAMP`.
  - Error messages, exact prefixes:
    - stat failure: `could not read vault <vault_path>: <errno message>`
    - child exits non-zero: `could not publish <vault_path> as a gem index: <child output, stripped>`
    - child killed: `could not publish <vault_path> as a gem index: the publishing process was killed by signal <n>`
    - child cannot start: `could not publish <vault_path> as a gem index: could not start <Gem.ruby>: <errno message>`

- [ ] **Step 1: Update and extend the spec:**
  - `subject` becomes `described_class.new(vault_path, shelf: Gemvault::Shelf.new(shelf_directory))`; rename `let(:shelf)` to `let(:shelf_directory)`. Replace `shelf.children.size` assertions with `shelf_directory.glob("*-*-*").size` (the shelf now also holds `.lock`).
  - "when the file is not a vault": also `raise_error(Error, /as a gem index: .+/m)` so the cause is present.
  - "when the vault file is missing" (`vault_path` never created): `raise_error(Error, /could not read vault .*test\.gemv/)`.
  - "when the publishing process cannot start" (`allow(Gem).to receive(:ruby).and_return((gem_dir / "no-ruby").to_s)`): `raise_error(Error, /could not start/)`.
  - "when only the vault's modification time changes" (publish, `age(vault_path)`, publish): the two `url`s differ.
  - "when only the vault's size changes" (record `File.mtime(vault_path)`; publish; add `bar-2.0.0` through `open_vault`; restore the recorded mtime with `File.utime`; publish again): `published_gems` contains `bar-2.0.0.gem`.
  - "when the caller's RUBYOPT preloads a file" (mirror the existing `BUNDLER_SETUP` context: `ENV["RUBYOPT"] = "-r#{marker_script}"`): the marker file does not exist after `publish`.
  - Activation examples: build the child environment from `described_class::BUNDLER_VARIABLES.to_h { [it, nil] }` and pass it as the first argument to `Open3.capture2e`. The script also calls `Gemvault::Shelf.new(ARGV.fetch(1)).usable?` and `Gemvault::SourceAddress.new("https://gemvault.invalid/test.gemv/")` (require both files). Add the control example "detects a gem activated in the calling process": same harness with `require "zlib"` prepended to the script, expecting output to include `"zlib"`.
- [ ] **Step 2: Run** `bundle exec rspec spec/gemvault/vault_publication_spec.rb` — Expected: FAIL on the new examples; the control example PASSES only with the cleared environment (confirm it fails if you temporarily drop the env argument, then restore).
- [ ] **Step 3: Commit the spec** — `git commit -m "Specify why a vault could not be published"`
- [ ] **Step 4: Implement.**
  - `vault_publication.rb`: `require_relative "shelf"`. `publish` asks `@shelf.index_for(stamp)`. `stamp` wraps `File.stat` in `begin/rescue SystemCallError` and raises `Error`. Replace `system` with `IO.popen(OUTSIDE_THE_BUNDLE, [Gem.ruby, SCRIPT, @vault_path, @shelf.directory, stamp], err: %i[child out], &:read)`, then branch on `$?` (`Process.last_status`): success returns the index; `signaled?` and non-zero raise per Interfaces; `rescue SystemCallError` around the popen gives "could not start". Fix the class comment: "requires no gem and activates nothing" and "other default gems" (no count); "recognised without opening it".
  - `publish_static_index.rb`: take `vault_path, shelf_directory, stamp`; body is `Gemvault::Shelf.new(shelf_directory).stock(stamp) { |index| Gemvault::Vault.open(vault_path) { |vault| index.publish(vault) } }`. Rescue only `Gemvault::Vault::Error` and `SystemCallError` and `abort e.message`; anything else propagates with its backtrace. If the "not a vault" example shows another expected error class, add that class to the rescue rather than widening to `StandardError`. Update the header comment to the new usage line.
- [ ] **Step 5: Run** `bundle exec rspec spec/gemvault` under the systemd cap — Expected: PASS. **Commit** — `git commit -m "Report why publishing a vault failed"`

### Task 4: `SourceAddress` stays inside what it documents

**Files:** Modify `lib/gemvault/source_address.rb`, `spec/gemvault/source_address_spec.rb`

**Interfaces:** Produces: `SourceAddress.vaulted?` / `.new` reject a vault path that starts with `/`. `SourceAddress.for` is removed (no production caller). `PATTERN = %r{\Ahttps://gemvault\.invalid/(?<vault_path>[^/?#](?:[^?#]*[^/?#])?)/?\z}` (keep the `HOST` interpolation).

- [ ] **Step 1: Add failing examples** (each `vaulted?` false and `new` raising `ArgumentError`): `https://gemvault.invalid//etc/x.gemv/`. Add passing-by-design pins: query `?a=1`, fragment `#x`, `http://` scheme, `https://gemvault.invalid.example.com/x.gemv/`, `https://gemvault.invalid:8443/x.gemv/` are all not vaulted; `https://gemvault.invalid/../shared/x.gemv/` is vaulted with `vault_path == "../shared/x.gemv"`; `new("https://gemvault.invalid/x.gemv").to_s == "https://gemvault.invalid/x.gemv/"`; `vaulted?(Gem::URI("https://gemvault.invalid/x.gemv/"))` is true. Delete the `.for` examples.
- [ ] **Step 2: Run** `bundle exec rspec spec/gemvault/source_address_spec.rb` — Expected: the `//etc` example FAILS. **Commit the spec** — `git commit -m "Specify the addresses that do not name a vault"`
- [ ] **Step 3: Implement** the pattern, delete `.for`, and change the rdoc from "relative to the Gemfile" to "resolved against the Gemfile's directory; it may climb with `..` but may not be absolute".
- [ ] **Step 4: Run** — Expected: PASS. **Commit** — `git commit -m "Refuse an address that names an absolute vault path"`

### Task 5: `VaultRedirection` picks a usable shelf and confirms the mirror

**Files:** Modify `lib/bundler/plugin/vault_redirection.rb`, `spec/bundler/plugin/vault_redirection_spec.rb`

**Interfaces:**
- Consumes: `Shelf#usable?`, `Shelf#to_s`, `VaultPublication` (Task 3), `SourceAddress` (Task 4).
- Produces (behaviour):
  - Shelf candidates, first usable wins:
    1. `<app_config_path>/gemvault/<name>` when `app_config_path` is inside `Bundler.root`; otherwise `<app_config_path>/gemvault/<sha1 of root>/<name>`.
    2. `<user_cache>/gemvault/<sha1 of root>/<name>`.
    `<name>` is the vault path with `/` replaced by `%2F`; the digest is `Bundler::Digest.sha1(Bundler.root.to_s)`.
  - No usable candidate: `Bundler::PathError`, `"Could not publish vault '<vault_path>': neither <a> nor <b> can hold a gem index. Each must be writable and its path must hold no spaces and only ASCII characters. Set BUNDLE_USER_CACHE to such a directory"`.
  - After `set_command_option`, if `Bundler.settings.mirror_for(address.to_s).to_s != index.url`: `Bundler::PathError`, `"Bundler cannot mirror the vault address '<address>'. Rename the vault file so that no '_' sits next to another '_', a '.' or a '-'"`.
  - `Bundler.ui.debug("gemvault: <address> is served from <index.directory>")` after a successful redirect.
  - Vault lookup: `File.file?` → proceed; `File.directory?` → `PathError "Vault '<path>' referenced in Gemfile is a directory, not a vault file"`; otherwise the existing "Could not find vault" message.
  - `VaultPublication::Error` → `Bundler::PathError` with the same message (unchanged), which now carries the cause.

- [ ] **Step 1: Rework the spec.**
  - Replace `instance_spy(Bundler::Settings)` with `let(:settings) { Bundler::Settings.new(project / ".bundle") }`; stub `Bundler.ui` with `instance_spy(Bundler::UI::Silent)`. Mirror assertions become `expect(settings.mirror_for(address).to_s).to start_with(shelf_url)`; "sets no mirror" becomes `settings.mirror_for("https://rubygems.org/").to_s == "https://rubygems.org/"`.
  - Remotes are `Gem::URI` objects: `let(:remotes) { [Gem::URI("https://gemvault.invalid/test.gemv/")] }`.
  - Keep the existing fallback, two-projects and neither-usable contexts (message expectations: `/BUNDLE_USER_CACHE/` and `/test\.gemv/`).
  - New contexts:
    - "when the vault sits in a subdirectory" (`vendor/test.gemv`): the index is under `.bundle/gemvault/vendor%2Ftest.gemv/` and `mirror_for("https://gemvault.invalid/vendor/test.gemv/")` points there.
    - "when two sources are addressed to vaults": both mirrors set.
    - "when the project directory is read-only" (`chmod 0555` on `project`, vault created first, restored in `after`): the index is under `user_cache`.
    - "when the bundle's config directory is outside the project" (`app_config_path: gem_dir / "global"`): the index is under `global/gemvault/<40 hex>/test.gemv/`.
    - "when Bundler cannot carry the vault path in a mirror" (vault at `my__vault.gemv`): `raise_error(Bundler::PathError, /my__vault\.gemv/)`.
    - "when the addressed path is a directory": `raise_error(Bundler::PathError, /is a directory/)`.
    - "when the vault cannot be published" (`vault_path.write("not a vault")`): `raise_error(Bundler::PathError, /as a gem index: .+/m)`.
    - "reports where the index is served from": `Bundler.ui` received `debug` with `/served from/`.
- [ ] **Step 2: Run** `bundle exec rspec spec/bundler/plugin/vault_redirection_spec.rb` — Expected: FAIL on the new contexts. **Commit the spec** — `git commit -m "Specify choosing a usable shelf and confirming the mirror"`
- [ ] **Step 3: Implement** per Interfaces. `require_relative "../../gemvault/shelf"`. Keep the one-call-per-line pipeline in `apply`. Update the class rdoc for the shelf rule.
- [ ] **Step 4: Run** `bundle exec rspec spec/gemvault spec/bundler` and `bundle exec rubocop` — Expected: PASS, no offenses. **Commit** — `git commit -m "Choose a usable shelf and confirm Bundler took the mirror"`

### Task 6: Integration scenarios

**Files:** Modify `spec/support/addressed_vault_scenarios.rb`, `spec/integration/addressed_vault_spec.rb`

**Interfaces:** Consumes: `run_bundle(gemfile_content:, assertions:, gems:, dependencies:)`, `GemIndex.source_line`, `GemIndex.with_source` (skips adding a source when the content already has `source "http`), matchers `succeed`, `succeed_showing`, `fail_showing`. `run_addressed(steps, project:)` already exists; add a `gemfile:` keyword defaulting to `ADDRESSED_GEMFILE`.

- [ ] **Step 1: Add scenarios and examples** (one container each; keep them few):
  - "alongside another gem source": Gemfile is `GemIndex.source_line`, the addressed block, and one gem served by the local index (pick one already in the index; see `spec/support/gem_index.rb`). Assert `succeed_showing` two `remote:` lines (`remote: https://gemvault.invalid/test.gemv/` and the index URL) and that both gems load.
  - "when the vault sits in a subdirectory": `mkdir vendor; mv test.gemv vendor/`, address `https://gemvault.invalid/vendor/test.gemv/`; installs and loads.
  - "when the project is moved after the plugin was installed": after `bundle install`, `cp -a` the project to a sibling directory, `rm -rf` the original, delete `.bundle/gemvault` in the copy, run `bundle install` and the load check there.
  - "when the vault changes after installing": after `bundle install`, `touch test.gemv`, then `bundle exec ruby -e ...` loads the gem (exercises publishing from under `bundle exec`).
  - Strengthen existing examples: the load check prints `loaded #{VaultTestGem::VERSION}` and examples assert `"loaded 1.0.0"`; the missing-vault example uses `fail_showing("Could not find vault 'test.gemv'")`; the no-mirror example also asserts the `bundle config list` heading is shown.
  - Replace the three-line header comment in `addressed_vault_scenarios.rb` with one line: "Projects whose Gemfile names its vault as an ordinary gem source address."
- [ ] **Step 2: Run** `bundle exec rake spec:build` then `bundle exec rspec spec/integration/addressed_vault_spec.rb` under the systemd cap — Expected: PASS (the code is already in place; a failure here is a real bug to fix in the owning task's file, spec first).
- [ ] **Step 3: Commit** — `git commit -m "Specify addressed vaults beside other sources and after a move"`

### Task 7: Plugin installed before Bundler gained the hook

**Files:** Modify `spec/support/addressed_vault_scenarios.rb`, `spec/integration/addressed_vault_spec.rb`, `README.md`, `CHANGELOG.md`

- [ ] **Step 1: Add one scenario:** install the plugin on the image's Bundler 4.0.23, then install Bundler 4.1.0, export `BUNDLER_VERSION`, run `bundle install` (expected to fail naming `gemvault.invalid`, tolerate with `|| true`), then run `bundle plugin uninstall bundler-source-vault && bundle plugin install bundler-source-vault` and `bundle install` plus the load check. Example: "installs once the plugin is reinstalled on the newer Bundler" → `succeed_showing("loaded 1.0.0", "gemvault.invalid")`.
- [ ] **Step 2: Run it.** Expected: PASS. If the first `bundle install` already succeeds (the hook fires without a reinstall), the finding is wrong: drop the scenario and the doc line and say so in the PR body.
- [ ] **Step 3: Document** in the README bullet list and CHANGELOG entry: "After upgrading to Bundler 4.1.0, or upgrading the plugin, reinstall it (`bundle plugin uninstall bundler-source-vault`, then `bundle plugin install bundler-source-vault`): Bundler records a plugin's hooks when it is installed." No runtime warning is added: it would fire for every `type: :vault` user on an older Bundler who never uses an address.
- [ ] **Step 4: Commit** spec, then docs, as two commits.

### Task 8: Comments and documentation

**Files:** Modify `README.md`, `CHANGELOG.md`, `CLAUDE.md`, `shim/plugins.rb`, `lib/gemvault/static_index.rb`, `lib/gemvault/vault_publication.rb`

- [ ] **Step 1: Settle the resolution claim.** In a scratch project under `/workspace/tmp` with one rubygems.org gem and one addressed vault, on Bundler 4.1.0, run `bundle lock --verbose` twice: once addressed, once with `type: :vault`. Record whether rubygems.org is read through the compact index in both, and whether the "scoped sources that don't implement a dependency API" warning prints. Then word `README.md:79-80` and the PR body from what was observed: either "Bundler reads the vault's full index and warns that the source has no dependency API", or keep "every source" if rubygems.org really falls back. Do not keep an unverified claim.
- [ ] **Step 2: Apply the corrections:**
  - `CHANGELOG.md`: "Requires Bundler 4.1.0 or newer and the plugin installed with `bundle plugin install`; commit `.bundle/plugin` so Dependabot's clone has it."
  - `CLAUDE.md:100` and the comments in `vault_publication.rb` / `static_index.rb`: "requires no gem (only RubyGems and its vendored URI) and activates nothing"; refer to `BUNDLER_VARIABLES` instead of naming two variables; add a `lib/gemvault/shelf.rb` architecture line; `vault_publication.rb` line no longer says the shelf is under `.bundle/gemvault/`.
  - `shim/plugins.rb:30-31`: "an older one keeps the vault source type; an addressed vault there is left unredirected and fails as an unreachable host." Line 12-13: "the registrations below still repeat".
  - `README.md` new bullets: the index location rule (project `.bundle/gemvault/`, or the Bundler cache when the project path cannot be addressed or written, or when `BUNDLE_APP_CONFIG` points outside the project); a vault file name may not put `_` next to `_`, `.` or `-`; Bundler sends setting names in its User-Agent, so the vault's relative path is visible to the gem servers the bundle contacts (confirm first: `Bundler::Fetcher#user_agent` in the Bundler 4.1.0 source; if it redacts or omits `mirror.*` keys in 4.1.0, leave the bullet out); a `bundle` run that started before the vault changed may need rerunning.
- [ ] **Step 3: Run** `bundle exec rubocop` — Expected: no offenses. **Commit** — `git commit -m "Correct the addressed-vault documentation"`

### Task 9: Verify, push, update the PR

- [ ] **Step 1:** `bundle exec rake spec:build` then `bundle exec rake` under the systemd cap. Expected: minitest 0 failures; RSpec 0 failures with 1 pending (the existing upstream plugin-reinstall expectation); RuboCop clean; RubyCritic ≥ 90.
- [ ] **Step 2:** Re-run the native end-to-end check on Bundler 4.1.0 for a project under `.../My Projects/app`: fresh `bundle install` succeeds and the gem loads.
- [ ] **Step 3:** `git push` (plain). Update the PR description with a "Second review" section listing each finding and its fix, the new numbers, and the accepted limitation. Post nothing else to GitHub.
