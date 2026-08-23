# Ambient Plugin Registration Self-Heal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix issue #31 — a vault-installed executable (and every `bundler/setup` entry) dies with `undefined method 'new' for nil` once the ambient gem-home copy of `bundler-source-vault` that Bundler's plugin index points at goes away.

**Architecture:** Bundler's Gemfile-driven plugin installer skips extracting a plugin that is already installed as an ambient gem and records the *gem home's* absolute paths in the project's `.bundle/plugin/index`, never populating the plugin root. Since bundler 2.6.0, `Plugin.load_plugin` silently skips a plugin whose recorded paths no longer exist (the warning is swallowed by `bundler/setup`'s `Bundler.ui.silence`), so `Plugin.source("vault")` returns nil and `SourceList#add_plugin_source` crashes. The fix settles such a registration **while the recorded copy is still alive**: a new `Gemvault::AmbientRegistration` copies the payload and its installation record into the plugin root and repoints the index at the copy, invoked from `Bundler::Plugin::VaultSource#initialize` — the one moment gemvault code reliably runs on a poisoned-but-alive machine. A machine already decayed (or wrecked by moving the project directory, which the self-heal cannot reach) is repaired by the existing `gemvault doctor`; this plan adds the integration spec proving it. No shim changes, no new dependencies, no doctor changes.

**Tech Stack:** Ruby ≥ 3.4.8, RSpec (unit + podman integration suite), Minitest (library), bundler 4.0.17 (pinned in `Dockerfile.test`), textual index rewriting (no YAML library — house rule).

**Spec:** The failing contract is `spec/integration/vault_installed_executable_spec.rb` ("still runs against the project's bundle" — red today with the verbatim reported crash). Mechanism analysis and verified reproductions: `_claude/demos/issue-31/README.md` (+ `micro.sh`, `demo.sh`). Issue text: `issues.rec` id 31.

**Evidence already gathered (2026-08-18, host probes on rbenv 3.4.9 + bundler 4.0.17):**
- A hand-performed settle (payload copy + spec copy + textual index repoint) satisfies bundler after the ambient copy is uninstalled: the tool prints its greeting.
- Directories must be created mode `0755` and files `0644` explicitly — on filesystems with default ACLs, inherited world-writable modes later make RubyGems refuse to replace the copy ("unsafe to remove").
- Today's `gemvault doctor` fully recovers the moved-project flavor: `bundle plugin uninstall` unregisters the dead entry, the reinstall repopulates the root, exit 0, tool runs. Its issue-#27 transactional restore also engaged correctly when a reinstall was forced to fail.

## Global Constraints

Every task's requirements implicitly include these (from `CLAUDE.md` and the harness):

- Specs come first; the plan's spec skeletons below are the starting point. Spec files never contain comments.
- Do NOT modify `.rubocop.yml` or `.rubycritic.yml`, and no inline `rubocop:disable` / rubycritic exemptions.
- NEVER create a class whose name ends in "-er" or "-or". NEVER use Ruby's `sleep`.
- Nothing in `lib/` may `require "json"` or load a YAML library; the plugin index is rewritten as lines of text (precedent: `Gemvault::ManifestText`, `Gemvault::BundlerPluginIndex`). Add no stdlib requires beyond `pathname` on the bundler-process path.
- No new runtime dependencies; no git history rewriting.
- NEVER write to `/tmp` on the host — use the repo's `tmp/` (gitignored); inside containers use `$WORKDIR`.
- Container fidelity rules in `CLAUDE.md` are load-bearing: never export `GEM_HOME`/`GEM_PATH` in `Dockerfile.test` or `podman_run`, never install `bundler-source-vault` system-wide in the image, integration scripts run only commands a user would actually type.
- The default rake gauntlet must stay green: `test`, `spec`, `rubocop` (0 offenses), `rubycritic` (score ≥ 90).
- This codespace's ruby is 3.4.7 (< gemspec floor 3.4.8); run everything through rbenv 3.4.9 with a scrubbed environment (rvm hooks contaminate subprocesses):
  `env -i HOME="$HOME" PATH="/home/codespace/.rbenv/versions/3.4.9/bin:/usr/bin:/bin" bash -c '<command>'`
- `rake spec:integration` requires podman + `rake spec:build`; run those tasks on a podman-capable machine. Everything else runs here.
- Every commit message ends with:
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`

## Spec Skeletons (write these first — the whole plan implements them)

```ruby
RSpec.describe Gemvault::BundlerPluginIndex do
  describe "#recorded_path" do
    it "answers the path plugin_paths records for the plugin"
    it "is nil when the plugin is not registered"
    it "is nil when the index was emptied"
    it "is nil when no index exists"
  end

  describe "#repoint" do
    it "rewrites plugin_paths to the destination"
    it "rewrites a load_paths entry recorded with bundler's trailing /. variant"
    it "leaves other plugins' records alone"
    it "leaves the file alone when the plugin is not registered"
  end
end

RSpec.describe Gemvault::AmbientRegistration do
  describe ".of" do
    it "finds a registration recorded at an installed gem outside every root"
    it "is nil when the recorded path lies inside a plugin root"
    it "is nil when no installation record sits beside the recorded path"
    it "is nil when nothing is registered"
  end

  describe "#settle" do
    it "copies the payload into the root's gems directory"
    it "copies the installation record into the root's specifications"
    it "repoints the index at the copy"
    it "leaves an existing copy in place"
    it "creates directories closed to group and world writing"
  end

  describe ".settle" do
    it "raises nothing at a machine it cannot write to"
    it "leaves a machine it cannot write to as found"
  end
end

RSpec.describe "an executable installed from a vault", :integration do
  it "runs against the project's bundle"                                  # exists, green

  context "when the shim recorded in the plugin index has left the gem home" do
    it "still runs against the project's bundle"                          # exists, RED -> green (Task 5)
  end

  context "when the project directory was moved after bundling" do        # Task 6
    it "dies inside bundler rather than running"
    context "when the doctor is run after the failure" do
      it "runs against the project's bundle"
    end
  end
end
```

## File Structure

- Modify: `lib/gemvault/bundler_plugin_index.rb` — grows `#recorded_path` and `#repoint`; stays the single owner of "Bundler's plugin index file inside a plugin root".
- Create: `lib/gemvault/ambient_registration.rb` — `Gemvault::AmbientRegistration`, the pathology + remedy object (shape mirrors `Gemvault::GhostSpecification`): detection (`.of`) and relocation (`#settle`).
- Modify: `lib/bundler/plugin/vault_source.rb:13-17` — one settle call in `#initialize`.
- Modify: `spec/gemvault/bundler_plugin_index_spec.rb` — new describes.
- Create: `spec/gemvault/ambient_registration_spec.rb`.
- Modify: `spec/support/vault_installed_executable.rb` — moved-project scenario fragments.
- Modify: `spec/integration/vault_installed_executable_spec.rb` — moved-project + doctor context.
- Modify: `CHANGELOG.md`, `issues.rec`, `CLAUDE.md` — resolution records.

Branch first: `git checkout -b fix/issue-31-ambient-plugin-registration` (create an isolated worktree via superpowers:using-git-worktrees if executing outside this checkout).

---

### Task 1: BundlerPluginIndex#recorded_path

**Files:**
- Modify: `lib/gemvault/bundler_plugin_index.rb` (class currently ends at line 58)
- Test: `spec/gemvault/bundler_plugin_index_spec.rb`

**Interfaces:**
- Consumes: existing private `#plugin_paths` (returns the indented lines of the `plugin_paths:` section).
- Produces: `recorded_path(plugin) -> String | nil` — the double-quoted path bundler's emitter recorded for `plugin`, without quotes. Task 3 detects ambience with it; Task 2's `#repoint` uses it internally.

- [ ] **Step 1: Write the failing specs**

Add to `spec/gemvault/bundler_plugin_index_spec.rb` (inside the existing top-level describe, after the `#registered?` block; the `registering`/`emptied` lets and `write_index` helper already exist):

```ruby
  describe "#recorded_path" do
    it "answers the path plugin_paths records for the plugin" do
      write_index(registering)
      expect(index.recorded_path("bundler-source-vault")).to eq("/roots/plugin/gems/bundler-source-vault-0.2.5")
    end

    it "is nil when the plugin is not registered" do
      write_index(registering)
      expect(index.recorded_path("bundler-source-fake")).to be_nil
    end

    it "is nil when the index was emptied" do
      write_index(emptied)
      expect(index.recorded_path("bundler-source-vault")).to be_nil
    end

    it "is nil when no index exists" do
      expect(index.recorded_path("bundler-source-vault")).to be_nil
    end
  end
```

- [ ] **Step 2: Run to verify failure**

Run: `env -i HOME="$HOME" PATH="/home/codespace/.rbenv/versions/3.4.9/bin:/usr/bin:/bin" bash -c 'bundle exec rspec spec/gemvault/bundler_plugin_index_spec.rb'`
Expected: 4 failures, `NoMethodError: undefined method 'recorded_path'`.

- [ ] **Step 3: Implement**

In `lib/gemvault/bundler_plugin_index.rb`, replace the body of `#registered?` and add `#recorded_path` plus a private `#record_line`:

```ruby
    # Whether plugin_paths currently lists +plugin+.
    def registered?(plugin)
      !record_line(plugin).nil?
    end

    # :call-seq:
    #   recorded_path(plugin) -> String or nil
    #
    # The installation path plugin_paths records for +plugin+, +nil+ when the
    # index does not list it. Bundler's emitter writes the value double-quoted.
    def recorded_path(plugin)
      record_line(plugin)&.slice(/: "(.*)"/, 1)
    end
```

and in the private section, above `#plugin_paths`:

```ruby
    def record_line(plugin)
      plugin_paths.find { |line| line.match?(/\A\s{2}#{Regexp.escape(plugin)}:/) }
    end
```

- [ ] **Step 4: Run to verify green**

Run: same rspec command.
Expected: all examples pass (including the pre-existing `#registered?`/`#snapshot`/`#restore` ones — `registered?` was refactored onto `record_line`).

- [ ] **Step 5: Commit**

```bash
git add lib/gemvault/bundler_plugin_index.rb spec/gemvault/bundler_plugin_index_spec.rb
git commit -m "feat: read a plugin's recorded installation path off the index

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: BundlerPluginIndex#repoint

**Files:**
- Modify: `lib/gemvault/bundler_plugin_index.rb`
- Test: `spec/gemvault/bundler_plugin_index_spec.rb`

**Interfaces:**
- Consumes: `recorded_path(plugin)` from Task 1; `file` (the index Pathname).
- Produces: `repoint(plugin, destination) -> nil` — rewrites every path the index records for `plugin` (the `plugin_paths` entry and the `load_paths` entry, the latter possibly carrying bundler's trailing `/.`) to `destination` (anything responding to `to_s`). No-op when the plugin is not registered. Task 4 calls it.

- [ ] **Step 1: Write the failing specs**

Add to the same spec file. The `registering` fixture records `/roots/plugin/gems/bundler-source-vault-0.2.5` in both sections; add a fixture matching what bundler actually emits for an ambient registration (trailing `/.` in load_paths, a second plugin present):

```ruby
  let(:ambient_registering) do
    <<~YAML
      ---
      commands:
      hooks:
      load_paths:
        bundler-source-fake:
        - "/roots/elsewhere/gems/bundler-source-fake-1.0.0/."
        bundler-source-vault:
        - "/roots/ambient/gems/bundler-source-vault-0.2.5/."
      plugin_paths:
        bundler-source-fake: "/roots/elsewhere/gems/bundler-source-fake-1.0.0"
        bundler-source-vault: "/roots/ambient/gems/bundler-source-vault-0.2.5"
      sources:
        fake: "bundler-source-fake"
        vault: "bundler-source-vault"
    YAML
  end

  describe "#repoint" do
    it "rewrites plugin_paths to the destination" do
      write_index(ambient_registering)
      index.repoint("bundler-source-vault", "/roots/plugin/gems/bundler-source-vault-0.2.5")
      expect(index.recorded_path("bundler-source-vault")).to eq("/roots/plugin/gems/bundler-source-vault-0.2.5")
    end

    it "rewrites a load_paths entry recorded with bundler's trailing /. variant" do
      write_index(ambient_registering)
      index.repoint("bundler-source-vault", "/roots/plugin/gems/bundler-source-vault-0.2.5")
      expect((root / "index").read).to include(%(- "/roots/plugin/gems/bundler-source-vault-0.2.5"))
    end

    it "leaves other plugins' records alone" do
      write_index(ambient_registering)
      index.repoint("bundler-source-vault", "/roots/plugin/gems/bundler-source-vault-0.2.5")
      expect(index.recorded_path("bundler-source-fake")).to eq("/roots/elsewhere/gems/bundler-source-fake-1.0.0")
    end

    it "leaves the file alone when the plugin is not registered" do
      write_index(emptied)
      index.repoint("bundler-source-vault", "/roots/plugin/gems/bundler-source-vault-0.2.5")
      expect((root / "index").read).to eq(emptied)
    end
  end
```

- [ ] **Step 2: Run to verify failure**

Run: the Task 1 rspec command.
Expected: 4 failures, `NoMethodError: undefined method 'repoint'`.

- [ ] **Step 3: Implement**

Add to `lib/gemvault/bundler_plugin_index.rb`, below `#recorded_path` (public section). The old path came out of this same file via `recorded_path`, so a quoted-string substitution rewrites exactly the two entries that carry it — the plugin's directory embeds its own full gem name, so no other plugin's entry can hold the same string:

```ruby
    # Rewrites every path the index records for +plugin+ -- the plugin_paths
    # entry and the load_paths entry, the latter with bundler's trailing "/."
    # variant -- to +destination+. A plugin the index does not list is left
    # untouched.
    def repoint(plugin, destination)
      old = recorded_path(plugin) or return

      file.write(file.read.gsub(%r{"#{Regexp.escape(old)}(/\.)?"}) { %("#{destination}") })
    end
```

- [ ] **Step 4: Run to verify green**

Run: same rspec command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/gemvault/bundler_plugin_index.rb spec/gemvault/bundler_plugin_index_spec.rb
git commit -m "feat: repoint a plugin's index record at a new installation

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: AmbientRegistration detection

**Files:**
- Create: `lib/gemvault/ambient_registration.rb`
- Create: `spec/gemvault/ambient_registration_spec.rb`

**Interfaces:**
- Consumes: `Gemvault::BundlerPluginIndex#recorded_path` (Task 1).
- Produces: `Gemvault::AmbientRegistration.of(plugin, roots:) -> AmbientRegistration | nil` — an instance when `roots` (plugin-root Pathname-ables, searched in order) hold an index recording `plugin` at an installed gem directory outside every root; nil for healthy, path:-installed, source-tree, or unregistered states. `PLUGIN = "bundler-source-vault"`. Instances are constructed only through `.of` (`new` is private). Task 4 adds `#settle`; Task 5 wires `.settle`.

- [ ] **Step 1: Write the failing specs**

Create `spec/gemvault/ambient_registration_spec.rb` (`gem_dir` comes from the `GemFixtures` include; specs contain no comments):

```ruby
require "gemvault/ambient_registration"

RSpec.describe Gemvault::AmbientRegistration do
  let(:plugin) { "bundler-source-vault" }
  let(:plugin_root) { gem_dir / ".bundle/plugin" }
  let(:global_root) { gem_dir / "home/.bundle/plugin" }
  let(:roots) { [plugin_root, global_root] }
  let(:gem_home) { gem_dir / "gemhome" }
  let(:ambient_dir) { gem_home / "gems/bundler-source-vault-9.9.9" }

  def install_ambient_shim
    ambient_dir.mkpath
    (ambient_dir / "plugins.rb").write("payload")
    (ambient_dir / "gemvault_load_path.rb").write("payload")
    (gem_home / "specifications").mkpath
    (gem_home / "specifications/bundler-source-vault-9.9.9.gemspec").write("record")
  end

  def register(path)
    plugin_root.mkpath
    (plugin_root / "index").write(<<~YAML)
      ---
      commands:
      hooks:
      load_paths:
        bundler-source-vault:
        - "#{path}/."
      plugin_paths:
        bundler-source-vault: "#{path}"
      sources:
        vault: "bundler-source-vault"
    YAML
  end

  describe ".of" do
    it "finds a registration recorded at an installed gem outside every root" do
      install_ambient_shim
      register(ambient_dir)
      expect(described_class.of(plugin, roots: roots)).not_to be_nil
    end

    it "is nil when the recorded path lies inside a plugin root" do
      register(plugin_root / "gems/bundler-source-vault-9.9.9")
      expect(described_class.of(plugin, roots: roots)).to be_nil
    end

    it "is nil when no installation record sits beside the recorded path" do
      install_ambient_shim
      (gem_home / "specifications/bundler-source-vault-9.9.9.gemspec").delete
      register(ambient_dir)
      expect(described_class.of(plugin, roots: roots)).to be_nil
    end

    it "is nil when nothing is registered" do
      expect(described_class.of(plugin, roots: roots)).to be_nil
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `env -i HOME="$HOME" PATH="/home/codespace/.rbenv/versions/3.4.9/bin:/usr/bin:/bin" bash -c 'bundle exec rspec spec/gemvault/ambient_registration_spec.rb'`
Expected: LoadError (`cannot load such file -- gemvault/ambient_registration`).

- [ ] **Step 3: Implement detection**

Create `lib/gemvault/ambient_registration.rb`:

```ruby
require "pathname"
require_relative "bundler_plugin_index"

module Gemvault
  ##
  # A bundler plugin registration whose recorded installation lives in a gem
  # home rather than a plugin root.
  #
  # Bundler's Gemfile-driven plugin installer skips extracting a plugin that
  # is already installed as an ordinary gem, and registers the gem home's
  # paths in the plugin index instead of populating the plugin root -- the
  # ambient state issue #13 documents. That registration works until the
  # recorded copy leaves the gem home (gem cleanup after an upgrade, a ruby
  # switch, an explicit uninstall), after which Bundler::Plugin.load_plugin
  # skips the plugin behind a warning that bundler/setup silences,
  # Plugin.source returns nil, and every Gemfile naming the source type dies
  # with NoMethodError inside SourceList#add_plugin_source (issue #31).
  #
  # Settling relocates the registration while the recorded copy is still
  # there: the payload and its installation record are copied into the plugin
  # root whose index registered the plugin, and the index is repointed at the
  # copy, which survives whatever later happens to the gem home. Directories
  # are created 0755 and files 0644 explicitly, because a copy inheriting
  # world-writable modes (umask oddities, default ACLs) is one RubyGems will
  # later refuse to replace.
  #
  # A registration recorded at a path with no installation record beside it
  # is a path: or git: plugin, or a source tree, and is deliberately left
  # alone: relocating one would detach a development flow from its tree.
  class AmbientRegistration
    PLUGIN = "bundler-source-vault".freeze

    def self.of(plugin, roots: bundler_roots)
      roots = roots.map { |root| Pathname(root) }

      roots.filter_map { |root| in_root(root, plugin, roots) }.first
    end

    def self.in_root(root, plugin, roots)
      index = BundlerPluginIndex.new(root)
      recorded = index.recorded_path(plugin) or return nil
      recorded = Pathname(recorded)
      return nil if roots.any? { |candidate| recorded.to_s.start_with?("#{candidate}/") }
      return nil unless installed_gem?(recorded)

      new(plugin: plugin, index: index, root: root, recorded: recorded,
          record: installation_record(recorded))
    end
    private_class_method :in_root

    # An installed gem's directory sits in <home>/gems with its record beside
    # it in <home>/specifications, by RubyGems' own install convention.
    def self.installed_gem?(recorded)
      recorded.directory? && installation_record(recorded).file?
    end
    private_class_method :installed_gem?

    def self.installation_record(recorded)
      recorded.parent.parent / "specifications" / "#{recorded.basename}.gemspec"
    end
    private_class_method :installation_record

    def self.bundler_roots
      return [] unless defined?(Bundler::Plugin)

      [Bundler::Plugin.root, Bundler::Plugin.global_root]
    end
    private_class_method :bundler_roots

    def initialize(plugin:, index:, root:, recorded:, record:)
      @plugin = plugin
      @index = index
      @root = root
      @recorded = recorded
      @record = record
    end
    private_class_method :new
  end
end
```

- [ ] **Step 4: Run to verify green**

Run: same rspec command. Expected: 4 examples, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add lib/gemvault/ambient_registration.rb spec/gemvault/ambient_registration_spec.rb
git commit -m "feat: detect a plugin registration left ambient in a gem home

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: AmbientRegistration#settle and the .settle boundary

**Files:**
- Modify: `lib/gemvault/ambient_registration.rb`
- Test: `spec/gemvault/ambient_registration_spec.rb`

**Interfaces:**
- Consumes: `BundlerPluginIndex#repoint` (Task 2); instance state from Task 3.
- Produces: `#settle -> nil` (relocates payload + record, repoints index; idempotent, resumable after a partial run) and `AmbientRegistration.settle(plugin = PLUGIN, roots: bundler_roots) -> nil` (the safe entry Task 5 calls: never raises `SystemCallError`, no-ops on healthy machines).

- [ ] **Step 1: Write the failing specs**

Add to `spec/gemvault/ambient_registration_spec.rb`:

```ruby
  describe "#settle" do
    let(:settled_dir) { plugin_root / "gems/bundler-source-vault-9.9.9" }

    before do
      install_ambient_shim
      register(ambient_dir)
    end

    it "copies the payload into the root's gems directory" do
      described_class.of(plugin, roots: roots).settle
      expect(settled_dir / "plugins.rb").to be_file
    end

    it "copies the installation record into the root's specifications" do
      described_class.of(plugin, roots: roots).settle
      expect(plugin_root / "specifications/bundler-source-vault-9.9.9.gemspec").to be_file
    end

    it "repoints the index at the copy" do
      described_class.of(plugin, roots: roots).settle
      recorded = Gemvault::BundlerPluginIndex.new(plugin_root).recorded_path(plugin)
      expect(recorded).to eq(settled_dir.to_s)
    end

    it "leaves an existing copy in place" do
      settled_dir.mkpath
      (settled_dir / "plugins.rb").write("already settled")
      described_class.of(plugin, roots: roots).settle
      expect((settled_dir / "plugins.rb").read).to eq("already settled")
    end

    it "creates directories closed to group and world writing" do
      described_class.of(plugin, roots: roots).settle
      expect(settled_dir.stat.mode & 0o022).to eq(0)
    end
  end

  describe ".settle" do
    before do
      install_ambient_shim
      register(ambient_dir)
    end

    def with_unwritable_root
      plugin_root.chmod(0o500)
      yield
    ensure
      plugin_root.chmod(0o755)
    end

    it "raises nothing at a machine it cannot write to" do
      expect { with_unwritable_root { described_class.settle(plugin, roots: roots) } }.not_to raise_error
    end

    it "leaves a machine it cannot write to as found" do
      before_settle = (plugin_root / "index").read
      with_unwritable_root { described_class.settle(plugin, roots: roots) }
      expect((plugin_root / "index").read).to eq(before_settle)
    end
  end
```

(The `0o500` root blocks `materialize`'s first `mkdir`, which raises `Errno::EACCES` before any index write, so the as-found assertion holds; the file itself stays readable throughout.)

- [ ] **Step 2: Run to verify failure**

Run: the Task 3 rspec command.
Expected: 7 failures — 5 × `NoMethodError: undefined method 'settle'` on the instance, 2 × on the class.

- [ ] **Step 3: Implement**

In `lib/gemvault/ambient_registration.rb`, add the class-level entry directly under `PLUGIN` (above `.of`):

```ruby
    # Relocates an ambient registration of +plugin+, when one exists, into the
    # plugin root that registered it. A machine this cannot be done on --
    # read-only roots, permission refusals -- is left as found.
    def self.settle(plugin = PLUGIN, roots: bundler_roots)
      of(plugin, roots: roots)&.settle
    rescue SystemCallError
      nil
    end
```

and the instance surface, below the constructor:

```ruby
    def settle
      materialize
      adopt(@record, specifications_dir / @record.basename)
      @index.repoint(@plugin, settled_dir)
    end

    private

    def settled_dir
      @root / "gems" / @recorded.basename
    end

    def specifications_dir
      ensure_dir(@root / "specifications")
    end

    def materialize
      return if settled_dir.directory?

      ensure_dir(@root / "gems")
      ensure_dir(settled_dir)
      @recorded.children.select(&:file?).each { |file| adopt(file, settled_dir / file.basename) }
    end

    def adopt(source, target)
      return if target.file?

      target.binwrite(source.binread)
      target.chmod(0o644)
    end

    def ensure_dir(dir)
      dir.mkdir(0o755) unless dir.directory?
      dir
    end
```

- [ ] **Step 4: Run to verify green**

Run: same rspec command. Expected: all examples pass.

- [ ] **Step 5: Run the wider host gauntlet**

Run: `env -i HOME="$HOME" PATH="/home/codespace/.rbenv/versions/3.4.9/bin:/usr/bin:/bin" bash -c 'bundle exec rake test spec:core rubocop'`
Expected: minitest and spec:core fully green, rubocop 0 offenses.

- [ ] **Step 6: Commit**

```bash
git add lib/gemvault/ambient_registration.rb spec/gemvault/ambient_registration_spec.rb
git commit -m "feat: settle an ambient plugin registration into the plugin root

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Wire the settle into VaultSource and turn issue #31's red spec green

**Files:**
- Modify: `lib/bundler/plugin/vault_source.rb:1-17`
- Test (already written, currently RED): `spec/integration/vault_installed_executable_spec.rb` — "still runs against the project's bundle"

**Interfaces:**
- Consumes: `Gemvault::AmbientRegistration.settle` (Task 4, zero-argument form — defaults to the shim and `Bundler::Plugin`'s roots).
- Produces: no new interface; `VaultSource#initialize(opts)` behavior is otherwise unchanged.

- [ ] **Step 1: Confirm the integration spec is red for the right reason** (podman machine)

Run: `bundle exec rake spec:build && bundle exec rspec spec/integration/vault_installed_executable_spec.rb`
Expected: 1 failure — "still runs against the project's bundle", verdict showing exit status 1, `present but forbidden: "undefined method 'new' for nil"`. (Host fallback evidence if podman is unavailable: `_claude/demos/issue-31/demo.sh` exits 0 reproducing the crash.)

- [ ] **Step 2: Implement**

In `lib/bundler/plugin/vault_source.rb`, add to the requires (after line 4):

```ruby
require_relative "../../gemvault/ambient_registration"
```

and change `#initialize` (lines 13-17) to:

```ruby
      def initialize(opts)
        super
        # Instantiation is the one moment gemvault code reliably runs while an
        # ambient-recorded registration is still alive (issue #31); once the
        # gem home copy is gone, nothing of this plugin loads at all.
        Gemvault::AmbientRegistration.settle
        @vault_path = Pathname(@uri).expand_path(Bundler.root)
        @allow_remote = false
      end
```

- [ ] **Step 3: Run the host suites**

Run: `env -i HOME="$HOME" PATH="/home/codespace/.rbenv/versions/3.4.9/bin:/usr/bin:/bin" bash -c 'bundle exec rake test spec:core rubocop rubycritic'`
Expected: all green (minitest instantiates `VaultSource` directly; on a checkout with no `.bundle/plugin` index the settle is a nil no-op — see risk note below), rubycritic ≥ 90.

- [ ] **Step 4: Run the integration spec to verify green** (podman machine; the image rebuilds automatically — `SOURCE_DIGEST` changes with `lib/`)

Run: `bundle exec rake spec:build && bundle exec rspec spec/integration/vault_installed_executable_spec.rb`
Expected: both examples PASS — the wrecked-machine example now settles during the first `bundle install` (the poisoned index is written by `Plugin.gemfile_install` before the definition build instantiates the source), so the executable survives the ambient uninstall.

- [ ] **Step 5: Run the whole integration suite** (podman machine)

Run: `bundle exec rake spec:integration`
Expected: fully green — in every existing scenario the settle either no-ops (plugin properly in its root) or performs the relocation the wrecked scenario needed.

- [ ] **Step 6: Commit**

```bash
git add lib/bundler/plugin/vault_source.rb
git commit -m "fix: keep vault projects working after the ambient shim leaves (issue #31)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

**Risk note:** the settle runs on every `VaultSource` instantiation, including inside the minitest suite. On clean checkouts and CI there is no `.bundle/plugin/index`, so `recorded_path` is nil and nothing happens; on a developer machine whose project index really is ambient-poisoned, running the tests heals it — a write, but the beneficial one. If that ever proves surprising, the seam is `AmbientRegistration.settle`'s `roots:` parameter.

---

### Task 6: Integration spec — the moved project and the doctor

**Files:**
- Modify: `spec/support/vault_installed_executable.rb`
- Modify: `spec/integration/vault_installed_executable_spec.rb`

**Interfaces:**
- Consumes: `GemIndex.serve_preamble`, `VaultedApp.vendored_install`, the module's own `tool_vault_preamble`/`TOOL_GEM`/`machine_left_alone`, matchers `fail_showing`/`succeed_showing`.
- Produces: `run_relocated_tool(after_moving:)` and `doctor_after_the_crash` for the spec file.

The self-heal cannot reach this wreck — moving the project kills the recorded absolute paths with no alive-window in between — so the contract is the doctor's, which probe B verified recovers fully today. The crash-shape example pins the reported failure the way `ghost_plugin_spec.rb` does.

- [ ] **Step 1: Write the failing/verifying specs**

Append to the describe block in `spec/integration/vault_installed_executable_spec.rb`:

```ruby
  context "when the project directory was moved after bundling" do
    it "dies inside bundler rather than running" do
      expect(run_relocated_tool(after_moving: machine_left_alone)).to fail_showing(nil_plugin_source_crash)
    end

    context "when the doctor is run after the failure" do
      it "runs against the project's bundle" do
        expect(run_relocated_tool(after_moving: doctor_after_the_crash)).to succeed_showing(tool_greeting)
      end
    end
  end
```

- [ ] **Step 2: Add the scenario fragments**

In `spec/support/vault_installed_executable.rb`, add below `run_installed_tool` (public, above `private`):

```ruby
  def run_relocated_tool(after_moving:)
    podman_run(<<~SH)
      #{GemIndex.serve_preamble}
      #{tool_vault_preamble}
      #{project_beside_the_vault}
      #{VaultedApp.vendored_install}
      gem install --no-document --source $WORKDIR/test.gemv #{TOOL_GEM}
      cd $WORKDIR && mv app relocated && cd $WORKDIR/relocated
      #{after_moving}
      #{TOOL_GEM}
    SH
  end

  def doctor_after_the_crash
    <<~SH
      #{TOOL_GEM} && exit 90
      gemvault doctor
    SH
  end
```

and in the private section, below `tool_vault_preamble`:

```ruby
  # The reporter's layout: the vault lives outside the project, so moving the
  # project directory strands only the plugin index's recorded paths.
  def project_beside_the_vault
    <<~SH
      mkdir $WORKDIR/app
      cd $WORKDIR/app
      cat > Gemfile <<GEMFILE
      #{GemIndex.source_line}

      source "$WORKDIR/test.gemv", type: :vault do
        gem "vault_test_gem"
      end
      GEMFILE
    SH
  end
```

No ambient shim in this scenario: the plugin installs properly into `.bundle/plugin`, and the move alone creates the wreck. The `&& exit 90` guard (pattern from `VaultedProject.recovering_with_the_doctor`) makes sure the doctor is only ever credited with recovering from a failure that actually happened.

- [ ] **Step 3: Lint and dry-run**

Run: `env -i HOME="$HOME" PATH="/home/codespace/.rbenv/versions/3.4.9/bin:/usr/bin:/bin" bash -c 'bundle exec rubocop spec/support/vault_installed_executable.rb spec/integration/vault_installed_executable_spec.rb && bundle exec rspec --dry-run spec/integration/vault_installed_executable_spec.rb'`
Expected: 0 offenses; 4 examples registered.

- [ ] **Step 4: Run in the container** (podman machine)

Run: `bundle exec rspec spec/integration/vault_installed_executable_spec.rb`
Expected: 4 examples, 0 failures — the crash pin shows bundler's `nil` crash, the doctor context recovers to a running tool (probe B: "Uninstalled plugin bundler-source-vault" → "Installing bundler-source-vault 0.2.7" → "Bundle complete!" → greeting).

- [ ] **Step 5: Commit**

```bash
git add spec/support/vault_installed_executable.rb spec/integration/vault_installed_executable_spec.rb
git commit -m "test: prove the doctor recovers a project moved after bundling

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Documentation — CHANGELOG, issues.rec, CLAUDE.md

**Files:**
- Modify: `CHANGELOG.md` (first bullet under `## [Unreleased]` → `### Fixed`)
- Modify: `issues.rec` (issue Id 31: append resolution continuation lines, set `Status: closed`)
- Modify: `CLAUDE.md` (Architecture list, after the `ghost_specification.rb` line)

**Interfaces:**
- Consumes: nothing from other tasks; records what they did.
- Produces: nothing consumed later.

- [ ] **Step 1: CHANGELOG entry**

Insert as the first bullet under `### Fixed` in `## [Unreleased]`:

```markdown
- A plugin registration pointing into the gem home -- the state Bundler leaves
  behind when an ambient `bundler-source-vault` satisfies its plugin installer
  -- no longer breaks the project forever once that copy is cleaned up or the
  ruby is switched. The vault source settles such a registration into the
  plugin root while it is still alive, so `bundler/setup` (and every
  executable installed from a vault) keeps working after the ambient copy is
  gone; a machine already broken, or broken by moving the project directory,
  is repaired by `gemvault doctor` (issue #31).
```

- [ ] **Step 2: issues.rec resolution**

Append to issue Id 31's Description (as `+ ` continuation lines, matching the file's format) and flip its `Status: open` to `Status: closed`:

```
+ 
+ RESOLUTION: not a gemvault regression -- no gemvault code runs before the
+ crash, and the break predates 0.2.7. Bundler's plugin installer, finding
+ bundler-source-vault already installed as an ambient gem, skips populating
+ the plugin root and records the gem home's absolute paths in the project's
+ .bundle/plugin/index (the ambient state issues #13/#23 document). Since
+ bundler 2.6.0 (rubygems/rubygems 0c6ad3ecbb, still on master),
+ Plugin.load_plugin skips a plugin whose recorded paths no longer exist,
+ behind a warning bundler/setup's ui.silence swallows; Plugin.source("vault")
+ then returns nil and SourceList#add_plugin_source does nil.new -- the
+ reported error, with no remedy named. Any ordinary decay detonates it: gem
+ cleanup after upgrading gemvault (why the report blames 0.2.7), a ruby
+ switch, gem uninstall. Worth filing at rubygems/rubygems: the guard's
+ warning is both silenced under bundler/setup and followed by a crash it
+ predicted.
+ 
+ Gemvault::AmbientRegistration now settles the registration while the
+ recorded copy is still alive -- payload and installation record copied into
+ the plugin root, index repointed at the copy -- invoked from
+ VaultSource#initialize, so any bundle command during the alive window
+ immunizes the project. A registration with no installation record beside it
+ (path:, git:, source tree) is deliberately left alone. Machines already
+ decayed, or wrecked by moving the project directory (no alive window), are
+ repaired by gemvault doctor, whose uninstall-and-reinstall already handles
+ the dead-path entry.
+ 
+ Replicated first by spec/integration/vault_installed_executable_spec.rb --
+ the reported invocation verbatim: gem install --source out of a real vault,
+ the installed executable run through bundler/setup, real exit code -- red
+ with the reported NoMethodError before the fix. The moved-project flavor and
+ its doctor recovery are pinned in the same spec. Unit cover in
+ spec/gemvault/ambient_registration_spec.rb and the extended
+ bundler_plugin_index_spec.rb. Mechanism demos (poisoned index, silenced
+ warning, verbatim crash on bundler 2.6.9 and 4.0.17) live in
+ _claude/demos/issue-31/.
```

- [ ] **Step 3: CLAUDE.md architecture line**

After the `ghost_specification.rb` line in the Architecture list, add:

```markdown
- `lib/gemvault/ambient_registration.rb` — a plugin registration recorded in a gem home instead of the plugin root; settled into the root while the recorded copy is still alive (issue #31)
```

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md issues.rec CLAUDE.md
git commit -m "docs: record issue #31's resolution

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: Full verification

**Files:** none (verification only).

- [ ] **Step 1: Host gauntlet**

Run: `env -i HOME="$HOME" PATH="/home/codespace/.rbenv/versions/3.4.9/bin:/usr/bin:/bin" bash -c 'bundle exec rake test spec:core rubocop rubycritic'`
Expected: 115+ minitest assertions green, 360+ rspec examples green, 0 rubocop offenses, rubycritic ≥ 90.

- [ ] **Step 2: Container suite** (podman machine)

Run: `bundle exec rake spec:integration`
Expected: fully green, including all four `vault_installed_executable_spec.rb` examples.

- [ ] **Step 3: End-to-end demo re-run (optional, host)**

Run: `bash _claude/demos/issue-31/demo.sh`
Expected: now exits 1 with "UNEXPECTED: the tool ran on the decayed machine" — the demo asserts the *bug*, so the fix flips it; this is the designed signal that the demo (and its README's polarity note) should be updated or retired alongside the release.

- [ ] **Step 4: Hand off for merge**

Use superpowers:finishing-a-development-branch — the branch is ready for PR (`fix/issue-31-ambient-plugin-registration` → `master`; PR body ends with the Claude Code attribution line per harness rules). Version bump and release remain the maintainer's call.

---

## Self-Review

- **Spec coverage:** every skeleton example maps to a task (Tasks 1-4 unit, Task 5 turns the existing red contract green, Task 6 adds the moved-project pair). The reported invocation, the decay flavor, the no-window flavor, and the doctor recovery are all pinned.
- **Placeholder scan:** all steps carry real code, real commands, and expected outputs; no TBDs.
- **Type consistency:** `recorded_path`/`repoint` names match between Tasks 1-2 (definitions), Task 3-4 (consumers), and the specs; `AmbientRegistration.settle`'s zero-argument form in Task 5 matches Task 4's signature (`plugin = PLUGIN, roots: bundler_roots`); `run_relocated_tool(after_moving:)` matches between support and spec.
- **Known open risk:** Task 5's settle-inside-tests note; and the container runs (Tasks 5-6, 8) need a podman machine — every other step verifies on this codespace.
