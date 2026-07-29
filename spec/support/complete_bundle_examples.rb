RSpec.shared_examples "a complete bundle" do
  it "installs every gem in the Gemfile" do
    expect(gems_missing_from(bundle_output, expected_gems)).to be_empty, bundle_output
  end

  it "finishes without an error" do
    expect(bundle_status).to be_success, bundle_output
  end
end
