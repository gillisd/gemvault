require "test_helper"
require "gemvault/cli"
require "gemvault/cli/commands/doctor"

class CLIDoctorCommandTest < Minitest::Test
  def setup
    @calls = []
    @command = Gemvault::CLI::Commands::Doctor.new
    stub_command_calls
  end

  def test_run_uninstalls_bundler_source_vault_raising_on_failure
    catch(:exec_called) { @command.run }

    assert_equal [:system, ["bundle", "plugin", "uninstall", "bundler-source-vault"], { exception: true }], @calls.first
  end

  def test_run_execs_bundle_install_after_uninstalling
    catch(:exec_called) { @command.run }

    assert_equal [:exec, ["bundle", "install"], {}], @calls.last
  end

  def test_run_does_not_exec_bundle_install_before_uninstalling
    catch(:exec_called) { @command.run }

    system_index = @calls.index { |(kind, _)| kind == :system }
    exec_index = @calls.index { |(kind, _)| kind == :exec }

    assert_operator system_index, :<, exec_index
  end

  def test_run_does_not_install_when_uninstall_fails
    command = Gemvault::CLI::Commands::Doctor.new
    installed = false
    command.define_singleton_method(:system) { |*_args, **_kwargs| raise "uninstall failed" }
    command.define_singleton_method(:exec) { |*_args, **_kwargs| installed = true }

    assert_raises(RuntimeError) { command.run }
    refute installed
  end

  private

  def stub_command_calls
    calls = @calls
    @command.define_singleton_method(:system) do |*args, **kwargs|
      calls << [:system, args, kwargs]
      true
    end
    @command.define_singleton_method(:exec) do |*args, **kwargs|
      calls << [:exec, args, kwargs]
      throw(:exec_called)
    end
  end
end
