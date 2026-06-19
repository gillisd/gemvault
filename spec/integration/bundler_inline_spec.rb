RSpec.describe "bundler/inline with vault source", :integration do
  it "discovers the vault plugin and installs the gem", :aggregate_failures do
    output, status = run_inline_install
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("1.0.0")
  end
end
