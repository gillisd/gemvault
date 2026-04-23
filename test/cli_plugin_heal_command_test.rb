require "test_helper"
require "gemvault/cli"
require "gemvault/cli/commands/plugin_heal"

class CLIPluginHealCommandTest < Minitest::Test
  def setup
    @calls = []
    calls = @calls
    @command = Gemvault::CLI::Commands::PluginHeal.new
    @command.define_singleton_method(:system) do |*args|
      calls << [:system, args]
      true
    end
    @command.define_singleton_method(:exec) do |*args|
      calls << [:exec, args]
      throw(:exec_called)
    end
  end

  def test_run_uninstalls_bundler_source_vault_first
    catch(:exec_called) { @command.run }

    assert_equal [:system, ["bundle", "plugin", "uninstall", "bundler-source-vault"]], @calls.first
  end

  def test_run_execs_bundle_install_after_uninstalling
    catch(:exec_called) { @command.run }

    assert_equal [:exec, ["bundle", "install"]], @calls.last
  end

  def test_run_does_not_exec_bundle_install_before_uninstalling
    catch(:exec_called) { @command.run }

    system_index = @calls.index { |(kind, _)| kind == :system }
    exec_index = @calls.index { |(kind, _)| kind == :exec }

    assert_operator system_index, :<, exec_index
  end
end
