RSpec.shared_examples "a complete bundle" do
  it "installs every gem the Gemfile asks for, including the vaulted ones" do
    expect(gems_missing_from(bundle_output, expected_gems)).to be_empty, bundle_output
  end

  it "finishes without a problem" do
    expect(bundle_status).to be_success, bundle_output
  end
end
