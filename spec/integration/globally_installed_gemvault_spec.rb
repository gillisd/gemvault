RSpec.describe "a project with a gem that comes from a vault", :integration do
  include_context "when a project bundles a gem from a vault"

  context "when the user has installed gemvault globally on the machine" do
    let(:machine) { VaultedProject.gemvault_installed_globally }

    it_behaves_like "a complete bundle"
  end
end
