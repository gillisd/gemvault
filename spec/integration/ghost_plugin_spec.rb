RSpec.describe "a project with a gem that comes from a vault", :integration do
  include_context "when a project bundles a gem from a vault"

  context "when a ghost of the plugin gem haunts the machine's gem home" do
    let(:machine) { DistroRuby.ghost_of_ambient_shim }

    it "fails bundle install blaming the plugin's plugins.rb" do
      expect(bundle_output).to include("plugins.rb was not found in the plugin")
    end

    it "does not complete the bundle" do
      expect(bundle_status).not_to be_success, bundle_output
    end

    context "when the doctor is run after the failure" do
      let(:setup) { VaultedProject.recovering_with_the_doctor }

      it_behaves_like "a complete bundle"

      it "recovers from the reported failure rather than a healthy start" do
        expect(bundle_output).to include("plugins.rb was not found in the plugin")
      end

      it "reports the ghost it removed" do
        expect(bundle_output).to include("Removed ghost specification")
      end
    end
  end
end
