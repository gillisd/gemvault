require_relative "fixture_script"

# Issue #27: `gemvault doctor` run before the Gemfile's plugin path was
# corrected. The reinstall it hands to `bundle install` cannot succeed, and
# doctor has to put the index it cleared back rather than leave the machine
# with no plugin registered at all.
module DoctorReinstallFailureScenario
  Outcome = Data.define(:doctored, :index, :healed).freeze

  DOCTOR_MARK = "===DOCTOR_DONE===".freeze
  INDEX_MARK = "===INDEX_DONE===".freeze

  SCRIPT = <<~SH.freeze
    #{FixtureScript.preamble(gems: [["stranded_gem", "1.0.0"]])}
    set +e
    mkdir -p /tmp/strand-shim-a
    cat > /tmp/strand-shim-a/bundler-source-vault.gemspec <<'GEMSPEC'
    Gem::Specification.new do |s|
      s.name = "bundler-source-vault"
      s.version = "99.0.0"
      s.summary = "test shim"
      s.authors = ["t"]
      s.files = ["plugins.rb"]
      s.require_paths = ["."]
      s.add_dependency "gemvault"
    end
    GEMSPEC
    cat > /tmp/strand-shim-a/plugins.rb <<'PLUGINSRB'
    require "bundler/plugin/vault_source"
    Bundler::Plugin::API.source("vault", Bundler::Plugin::VaultSource)
    PLUGINSRB

    cd $WORKDIR
    cat > Gemfile <<GEMFILE
    source "https://rubygems.org"
    plugin "bundler-source-vault", path: "/tmp/strand-shim-a"
    source "$WORKDIR/test.gemv", type: :vault do
      gem "stranded_gem"
    end
    GEMFILE
    bundle install 2>&1

    mv /tmp/strand-shim-a /tmp/strand-shim-b
    gemvault doctor 2>&1
    echo "doctor exit: $?"
    echo "#{DOCTOR_MARK}"
    cat .bundle/plugin/index 2>&1
    echo "#{INDEX_MARK}"

    sed -i 's|/tmp/strand-shim-a|/tmp/strand-shim-b|' Gemfile
    gemvault doctor 2>&1
  SH

  def doctor_reinstall_failure_outcome
    output, = podman_run(SCRIPT)
    doctored, _, rest = output.partition(DOCTOR_MARK)
    index, _, healed = rest.partition(INDEX_MARK)
    Outcome.new(doctored: doctored, index: index, healed: healed)
  end
end

RSpec.configure do |config|
  config.include DoctorReinstallFailureScenario, :integration
end
