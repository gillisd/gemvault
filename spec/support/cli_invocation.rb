module CLIInvocation
  def invoke(command_class, *argv)
    command_class.main(argv)
  rescue SystemExit => e
    e.status
  end
end

RSpec.configure do |config|
  config.include CLIInvocation, file_path: %r{spec/gemvault/cli/}
end
