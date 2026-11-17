RSpec.describe "a project with a gem that comes from a vault", :integration do
  include_context "when a project bundles a gem from a vault"

  context "when a ghost of the plugin gem haunts the machine's gem home" do
    let(:machine) { DistroRuby.ghost_of_ambient_shim }

    it_behaves_like "a complete bundle"

    context "when the doctor is run" do
      let(:setup) { VaultedProject.running_the_doctor }

      it_behaves_like "a complete bundle"

      it "reports the ghost it removed" do
        expect(bundle_output).to include("Removed ghost specification")
      end
    end
  end
end
