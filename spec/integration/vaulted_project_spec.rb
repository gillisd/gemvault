RSpec.describe "a project with a gem that comes from a vault", :integration do
  include_context "when a project bundles a gem from a vault"

  context "with bundler left as it comes" do
    it_behaves_like "a project whose Gemfile uses a vault source"
  end

  context "when the user has chosen where gems are installed" do
    let(:setup) { VaultedProject.install_path_chosen }

    it_behaves_like "a project whose Gemfile uses a vault source"

    it "puts the gems where the user asked for them" do
      expect(bundle_output).to include(VaultedProject::CHOSEN_PATH_CONFIRMATION)
    end
  end

  context "when the user has undone their choice of where gems are installed" do
    let(:setup) { VaultedProject.install_path_removed }

    it_behaves_like "a project whose Gemfile uses a vault source"
  end

  context "when the user has cached the project's gems" do
    let(:setup) { VaultedProject.gems_cached }

    it_behaves_like "a project whose Gemfile uses a vault source"
  end
end
