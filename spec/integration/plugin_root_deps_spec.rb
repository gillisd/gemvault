RSpec.describe "loading the vault source with gemvault installed system-wide", :integration do
  it "survives a repeated bundle install", :aggregate_failures do
    output, status = install_twice_with_system_gemvault_present
    expect(second_install_output(output)).not_to include("cannot load such file")
    expect(second_install_output(output)).not_to include("Could not find")
    expect(status).to be_success, "second bundle install failed:\n#{output}"
  end

  it "loads under bundle exec, where GEM_PATH is restricted to the bundle", :aggregate_failures do
    output, status = bundle_exec_with_system_gemvault_present
    expect(output).not_to include("cannot load such file")
    expect(output).not_to include("Could not find")
    expect(status).to be_success, "bundle exec failed:\n#{output}"
  end
end
