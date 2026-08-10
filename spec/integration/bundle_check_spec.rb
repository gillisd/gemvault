RSpec.describe "bundle check with vault source", :integration do
  it "confirms the bundle is satisfied without crashing on a source lifecycle method" do
    expect(bundle_check_after_install)
      .to succeed_showing("The Gemfile's dependencies are satisfied").without("local_only!")
  end
end
