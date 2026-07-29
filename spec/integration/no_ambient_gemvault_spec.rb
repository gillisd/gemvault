RSpec.describe "a project with a gem that comes from a vault", :integration do
  include_context "when a project bundles a gem from a vault"

  context "when the user has no gemvault installed outside the project" do
    let(:setup) { VaultedProject.gemvault_uninstalled }

    it_behaves_like "a complete bundle"
  end
end
