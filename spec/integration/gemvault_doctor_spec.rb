RSpec.describe "a project with a gem that comes from a vault", :integration do
  include_context "when a project bundles a gem from a vault"

  context "when the user has run the doctor command" do
    let(:steps) { VaultedProject.running_the_doctor }

    it_behaves_like "a complete bundle"
  end
end
