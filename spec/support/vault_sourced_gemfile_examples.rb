RSpec.shared_examples "a project whose Gemfile uses a vault source" do
  it_behaves_like "a complete bundle"

  context "when the user has deleted Gemfile.lock" do
    let(:steps) { VaultedProject.deleting_the_lockfile }

    it_behaves_like "a complete bundle"
  end

  context "when the user has deleted the .bundle directory" do
    let(:steps) { VaultedProject.deleting_the_bundle_directory }

    it_behaves_like "a complete bundle"
  end

  context "when the user has deleted both Gemfile.lock and the .bundle directory" do
    let(:steps) { VaultedProject.deleting_the_lockfile_and_the_bundle_directory }

    it_behaves_like "a complete bundle"
  end

  context "when the user has removed the vaulted gem from the Gemfile" do
    let(:steps) { VaultedProject.removing_the_vaulted_gem }
    let(:expected_gems) { [] }

    it_behaves_like "a complete bundle"
  end

  context "when the user has added a gem from rubygems to the Gemfile" do
    let(:steps) { VaultedProject.adding_a_gem_from_rubygems }
    let(:expected_gems) { [VaultedProject::VAULTED_GEM, VaultedProject::RUBYGEMS_GEM] }

    it_behaves_like "a complete bundle"
  end

  context "when the user has added another gem from the same vault to the Gemfile" do
    let(:steps) { VaultedProject.adding_another_gem_from_the_same_vault }
    let(:expected_gems) { [VaultedProject::VAULTED_GEM, VaultedProject::COMPANION_VAULTED_GEM] }

    it_behaves_like "a complete bundle"
  end

  context "when the user has added a gem from a different vault to the Gemfile" do
    let(:steps) { VaultedProject.adding_a_gem_from_another_vault }
    let(:expected_gems) { [VaultedProject::VAULTED_GEM, VaultedProject::SECOND_VAULT_GEM] }

    it_behaves_like "a complete bundle"
  end
end
