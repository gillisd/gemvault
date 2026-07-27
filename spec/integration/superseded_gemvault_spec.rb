RSpec.describe "a project with a gem that comes from a vault", :integration do
  include_context "when a project bundles a gem from a vault"

  context "when a newer gemvault is also installed on the machine" do
    let(:machine) { VaultedProject.newer_gemvault_left_behind }

    it_behaves_like "a complete bundle"
  end
end
