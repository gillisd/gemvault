require "gemvault/cli"

class CLITestCase < Minitest::Test
  include GemvaultTestHelper

  def setup
    @tmpdir = Pathname(Dir.mktmpdir("gemvault_cli_test"))
    @gem_build_dir = @tmpdir / "gems"
    @gem_build_dir.mkpath
    @original_dir = Dir.pwd
    Dir.chdir(@tmpdir)
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@tmpdir)
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
