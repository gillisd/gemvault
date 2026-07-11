# Tarvault Spike — Findings

Spike for `docs/tarvault.md`: replace/augment the SQLite storage of a `.gemv`
with a **tarball** ("Tarvault") whose first entry is `manifest.json` and whose
remaining entries are `.gem` files. Motivation: drop the hard `sqlite3`
dependency (unportable, no JRuby) using only tooling that already ships with
rubygems.

## Result

Tarvault is implemented and wired **behind the existing `Gemvault::Vault`
facade**, so the CLI, the Bundler `type: :vault` source, and the RubyGems
`--source` path use it transparently:

- `Gemvault::Vault` is now a `Forwardable` delegator that selects a backend by
  file format — existing SQLite files open as `Gemvault::Dbvault` (the old code,
  extracted verbatim); new or tar files as `Gemvault::Tarvault`. New vaults are
  Tarvaults.
- Backends are **lazily required**, so a process that only touches Tarvaults
  never loads `sqlite3` — the JRuby-portability win.
- `Gemvault::Manifest` owns `manifest.json`; `Gemvault::TarArchive` owns the
  low-level tar read + atomic rewrite; `Gemvault::GemExtraction` /
  `Gemvault::VaultSession` are shared mixins.

**Drop-in proof:** the entire pre-existing suite passes with *no change to any
`spec/` behavior or integration file* — only new unit specs were added, plus two
Minitest assertions that had probed a SQLite closed-handle artifact.

- Minitest: `111 tests, 0 failures` (the Vault-contract, Bundler-source, and
  RubyGems-plugin tests now run on the **tar** backend via the facade).
- RSpec incl. podman integration: `88 examples, 0 failures` — real
  `bundle install` (`type: :vault`), `gem install --source myvault.gemv`,
  bundler-inline, and CLI, all against tar-backed vaults. *(Note: the container
  image must be rebuilt (`rake spec:build`) after code changes — a stale image
  silently tests old code and still passes on SQLite.)*
- New unit specs (`spec/gemvault/**`): `42 examples, 0 failures`.

A Tarvault on disk:

```
$ file myvault.gemv        # POSIX tar archive
$ tar -tf myvault.gemv
manifest.json
addressable-2.9.0.gem
rstore-0.3.9.gem
```

```json
// manifest.json
{
  "vault_version": "2",
  "format": "tarvault",
  "created_at": "2026-07-11 20:32:25",
  "gems": [
    { "name": "addressable", "version": "2.9.0", "platform": "ruby",
      "created_at": "…", "sha256": "7fdf6ac3…", "encrypted": false }
  ]
}
```

## Doc Q1 — Integrity: are checksums used?

Yes. Three layers exist; the manifest adds the one that matters for the container:

1. **Tar header checksum** — every 512-byte tar header carries an octal
   *byte-sum*. It protects the header only and is not cryptographic.
2. **Inside each `.gem`** — a `.gem` already contains `checksums.yaml.gz`
   (SHA256/SHA512 of its own members). This protects a gem's internals, not its
   identity within the vault.
3. **Manifest per-gem digest (added)** — each `manifest.json` record stores a
   cryptographic **SHA256 of the whole `.gem` blob**
   (`OpenSSL::Digest.new("SHA256")`, matching rubygems' own `Gem::Security`
   convention). `Tarvault#gem_data` recomputes and compares on read, raising
   `Vault::Error` on mismatch (verified by a test that flips a byte inside the
   stored blob).

**Boundary:** `gem_entries`/`specs` read the manifest and do **not** re-hash
blobs; only `gem_data` (the byte-serving path used by install/extract) verifies.
This is a deliberate scope for the spike — list operations stay O(manifest). If
list-time verification is ever wanted, the same `Manifest.digest` is the hook.

## Doc feasibility — the one-liner

`docs/tarvault.md`'s one-liner works, but for a subtle reason worth recording:

```ruby
Enumerator.new { |y|
  Gem::Package::TarReader.new(File.open(path)) { |r| r.each_entry { |e| y << Gem::Package.new(e) } }
}.map(&:spec)
```

`TarReader#each` **closes each entry after yielding** (verified: reading a
stashed entry raises `IOError: closed Entry`). The one-liner still returns
correct specs *only* because `Enumerator.new{}.map(&:spec)` interleaves
consumption — `.spec` runs while the entry is still open. Materialize the
packages first (`.to_a` then `map(&:spec)`, or stash the entries) and every
`.spec` raises `IOError`.

**Rule:** read specs eagerly, inside the iteration. Tarvault sidesteps the trap
entirely — it lists from the manifest and reads any single gem via
`TarReader#seek` into a private `StringIO`
(`Gem::Package.new(StringIO.new(entry.read)).spec`), never depending on
post-close entry behavior.

## Doc Q2 — Encryption: is it possible?

Yes (feasibility only — not implemented). `OpenSSL::Cipher` AES-256-GCM
round-trips raw `.gem` bytes cleanly (verified, incl. auth-tag failure on
tamper). The design already reserves the extension point: `Manifest::Record`
carries an `encrypted` flag (currently always `false`). Encryption would:

- encrypt the raw `.gem` bytes, store the ciphertext as the tar entry, and set
  `encrypted: true` plus cipher/iv/auth-tag on the record;
- `gem_data` decrypts (key from env/keyring) before returning, composing with
  the checksum by hashing the plaintext.

Because gemvault mediates every read and the manifest signals encryption, this
is a localized change in `gem_data`. `OpenSSL` ships on JRuby, so it does not
reintroduce a portability problem.

## Portability (the motivation)

The tar path uses only pure-Ruby rubygems tooling (`Gem::Package::TarReader`/
`TarWriter`), `OpenSSL`, and `JSON` — all present on JRuby. The facade lazily
`require`s `dbvault` (hence `sqlite3`) **only** when opening an existing SQLite
file, so a JRuby process that only touches Tarvaults never loads `sqlite3`.

**Follow-on:** to fully realize the portability win, make `sqlite3` an optional
runtime dependency in `gemvault.gemspec` once Dbvault read-compat is no longer
required.

## Atomicity & locking

Tar has no index, and the leading `manifest.json` changes size on every
mutation, so **every add/remove is a full rewrite** — to a sibling tempfile in
the target directory (same filesystem → atomic `File.rename`), with `fsync`
before rename. `flock` (the doc's suggestion) would guard concurrent *gemvault*
processes only; external tar edits remain unsupported by design and are out of
spike scope.

## Follow-on / productionization notes

- Optional `gemvault new --format {tar,db}` (default currently tar).
- Streaming rewrite: the current model reads all gem blobs into memory during a
  rewrite — fine for a spike; large vaults would want a copy-through stream.
- Make `sqlite3` optional in the gemspec (portability payoff).
- Encryption (`encrypted` flag → real cipher params).
- List-time integrity verification, if wanted.
- Unify the two backends' error taxonomy and temp-file logic once Tarvault is
  confirmed as "the way."

## Update — format versioning & `gemvault upgrade` (implemented)

A follow-up shipped explicit format versioning and a migration command:

- Each vault records an on-disk **format version** (`1` = Dbvault, `2` = Tarvault)
  read and validated on open. It is **decoupled from the gemvault gem version** —
  it bumps only when the byte layout changes. `Vault::UnsupportedVersionError` is
  raised for a vault newer than `Vault::CURRENT_FORMAT` instead of misreading it,
  closing the "reads fail open" hole.
- `Vault.backend_for` now positively identifies the container (`:sqlite`/`:tar`/
  `:unknown`) ahead of parsing and refuses unrecognized envelopes.
- `Gemvault::VaultUpgrade` (+ `gemvault upgrade`) reads a vault through its
  existing backend and rewrites it in the current format with an atomic swap,
  a default `.bak` backup, `--dry-run`, idempotency, and `created_at` preservation
  (the write path gained `add(created_at:)`).

Still open from the list above: optional `--format` on `new`, streaming rewrite,
optional `sqlite3` dependency, and encryption.
