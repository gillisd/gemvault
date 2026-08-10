require "test_helper"
require_relative "support/cli_test_case"

class CLITopLevelTest < CLITestCase
  def test_version
    assert_equal 0, run_cli("--version")
    assert_match(/gemvault #{Gemvault::VERSION}/o, @stdout)
  end

  def test_help
    assert_equal 0, run_cli("help")
    assert_match(/Usage/, @stdout)
  end

  def test_no_command_shows_help
    assert_equal 0, run_cli
    assert_match(/Usage/, @stdout)
  end

  def test_unknown_command
    assert_equal 1, run_cli("bogus")
    assert_match(/bogus/, @stderr)
  end
end
