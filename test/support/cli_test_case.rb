require "gemvault/cli"

class CLITestCase < Minitest::Test
  include GemvaultTestHelper

  def setup
    vault_workspace("gemvault_cli_test")
    @original_dir = Dir.pwd
    Dir.chdir(@tmpdir)
  end

  def teardown
    Dir.chdir(@original_dir)
    super
  end

  private

  def run_cli(*args)
    result = nil
    @stdout, @stderr = capture_io do
      result = Gemvault::CLI.main(args.map(&:to_s))
    end
    result
  end
end
