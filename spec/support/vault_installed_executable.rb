# The reported sequence of issue #31: a gem carrying an executable is
# installed straight from a vault with `gem install --source`, and the
# executable -- which requires bundler/setup, the way project CLIs do -- is
# run from the project whose Gemfile bundles gems out of the same vault.
#
# The machine is the reporter's: an ambient copy of the shim satisfied
# Bundler's plugin installer once, so the project's .bundle/plugin/index
# records gem-home paths. When that copy later leaves the gem home,
# Bundler::Plugin.load_plugin skips the plugin with a warning that
# bundler/setup silences, Plugin.source("vault") returns nil, and the
# Gemfile's vault source line dies with NoMethodError instead of a remedy.
module VaultInstalledExecutable
  TOOL_GEM = "vault_tool".freeze
  TOOL_GREETING = "vault_tool ready".freeze
  NIL_PLUGIN_SOURCE_CRASH = "undefined method 'new' for nil".freeze

  TOOL_EXECUTABLE = <<~RUBY.freeze
    #!/usr/bin/env ruby
    require "bundler/setup"
    puts "#{TOOL_GREETING}"
  RUBY

  TOOL_FILES = {
    "exe/#{TOOL_GEM}" => TOOL_EXECUTABLE,
    "lib/#{TOOL_GEM}.rb" => "module VaultTool; end",
  }.freeze

  def tool_greeting = TOOL_GREETING

  def nil_plugin_source_crash = NIL_PLUGIN_SOURCE_CRASH

  def machine_left_alone = ""

  def run_installed_tool(after_bundling:)
    podman_run(<<~SH)
      #{GemIndex.serve_preamble}
      #{DistroRuby.ambient_shim}
      #{tool_vault_preamble}
      #{VaultedApp.gemfile_with_index}
      #{VaultedApp.vendored_install}
      #{after_bundling}
      gem install --no-document --source $WORKDIR/test.gemv #{TOOL_GEM}
      #{TOOL_GEM}
    SH
  end

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

  private

  def tool_vault_preamble
    FixtureScript.preamble(gems: [["vault_test_gem", "1.0.0"], [TOOL_GEM, "1.0.0"]],
                           files: { TOOL_GEM => TOOL_FILES })
  end

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
end

RSpec.configure do |config|
  config.include VaultInstalledExecutable, :integration
end
