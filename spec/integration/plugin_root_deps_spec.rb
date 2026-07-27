RSpec.describe "a project with a gem that comes from a vault", :integration do
  context "when the user runs bundle install a second time" do
    let(:result) { install_twice_with_system_gemvault_present }
    let(:bundle_output) { result.first }
    let(:bundle_status) { result.last }

    it "installs the bundle" do
      expect(second_install_output(bundle_output)).to include("Bundle complete!")
    end

    it "finishes without an error" do
      expect(bundle_status).to be_success, bundle_output
    end
  end

  context "when the user runs the vaulted gem through bundle exec" do
    let(:result) { bundle_exec_with_system_gemvault_present }
    let(:bundle_output) { result.first }
    let(:bundle_status) { result.last }

    it "loads the vaulted gem" do
      expect(bundle_output).to include("1.0.0")
    end

    it "finishes without an error" do
      expect(bundle_status).to be_success, bundle_output
    end
  end
end
