RSpec.describe "bundle check with vault source", :integration do
  it "confirms the bundle is satisfied without crashing on a source lifecycle method", :aggregate_failures do
    output, status = bundle_check_after_install
    expect(status).to be_success, "bundle check failed:\n#{output}"
    expect(output).to include("The Gemfile's dependencies are satisfied")
    expect(output).not_to include("local_only!")
  end
end
