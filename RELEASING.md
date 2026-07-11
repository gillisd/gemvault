# Releasing gemvault

gemvault ships two platform variants of each version:

- `gemvault-X.Y.Z.gem`       — C Ruby, depends on `sqlite3`
- `gemvault-X.Y.Z-java.gem`  — JRuby, depends on `jdbc-sqlite3`

The `-java` gem can only be built under JRuby: the gemspec sets
`spec.platform = "java"` and depends on `jdbc-sqlite3` only when
`RUBY_ENGINE == "jruby"`. `sequel` is a dependency of both variants.

The gem requires MFA (`rubygems_mfa_required`), so pushes are done manually
with an OTP (or via rubygems trusted publishing if configured later).

## Steps

1. Bump `Gemvault::VERSION`, update `CHANGELOG.md`.
2. Build + push the C-Ruby gem (under MRI):
   ```bash
   bundle exec rake build           # => pkg/gemvault-X.Y.Z.gem
   gem push pkg/gemvault-X.Y.Z.gem
   ```
3. Build + push the JRuby gem (under JRuby):
   ```bash
   export PATH="$(rbenv root)/versions/jruby-10.1.0.0/bin:$PATH"
   export JAVA_HOME=/usr/lib/jvm/java-25-openjdk
   bundle exec rake build           # => pkg/gemvault-X.Y.Z-java.gem
   gem push pkg/gemvault-X.Y.Z-java.gem
   ```
4. Push the shim (unchanged, platform-agnostic):
   ```bash
   bundle exec rake shim:release
   ```
5. Tag and push: `git tag vX.Y.Z && git push --tags`.
