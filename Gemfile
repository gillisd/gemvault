source "https://rubygems.org"

gemspec

gem "gempilot", require: false
gem "minitest", "~> 6.0"
gem "minitest-reporters", "~> 1.8"
gem "rake"
gem "rspec", "~> 3.0"
gem "rubocop"
gem "rubocop-claude"
gem "rubocop-performance"
gem "rubocop-rake"
gem "rubocop-rspec"

# Not a runtime dependency (see gemvault.gemspec); needed here to exercise the
# legacy SQLite (Dbvault) read path and the `gemvault upgrade` migration. It is a
# C extension that cannot build on the JVM, so JRuby leaves it out -- nothing
# under test/ touches it, which is why the JRuby CI job runs `rake test` only.
gem "sqlite3", "~> 2.0", platform: %i[ruby windows]
