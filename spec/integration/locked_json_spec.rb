RSpec.describe "bundle exec against a project locking an older json", :integration do
  context "when a newer json is installed system-wide beside gemvault" do
    it "activates the locked json, never the newer one" do
      expect(bundle_exec_with_a_newer_json_installed)
        .to succeed_showing("1.0.0", "activated json #{JsonVersionSkew::LOCKED}")
        .without("You have already activated json", "json #{JsonVersionSkew::NEWEST} stand-in loaded")
    end
  end
end
