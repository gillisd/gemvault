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

  context "when the user has deleted everything bundler generated" do
    let(:steps) { VaultedProject.deleting_the_lockfile_and_the_bundle_directory }

    it_behaves_like "a complete bundle"
  end

  context "when the user has removed the vaulted gem from the Gemfile" do
    let(:steps) { VaultedProject.removing_the_vaulted_gem }
    let(:expected_gems) { [] }

    it_behaves_like "a complete bundle"

    it "stops installing the gem the user removed" do
      expect(listed_gems(bundle_output)).not_to include(VaultedProject::VAULTED_GEM)
    end
  end

  {
    "when the user has added a gem from rubygems to the Gemfile" =>
      [VaultedProject.adding_a_gem_from_rubygems,
       [VaultedProject::VAULTED_GEM, VaultedProject::RUBYGEMS_GEM]],
    "when the user has added their own project's gemspec to the Gemfile" =>
      [VaultedProject.adding_the_projects_own_gemspec,
       [VaultedProject::VAULTED_GEM, VaultedProject::OWN_GEM, VaultedProject::RUBYGEMS_GEM]],
    "when the user has added another gem from the same vault to the Gemfile" =>
      [VaultedProject.adding_another_gem_from_the_same_vault,
       [VaultedProject::VAULTED_GEM, VaultedProject::COMPANION_VAULTED_GEM]],
    "when the user has added a gem from a different vault to the Gemfile" =>
      [VaultedProject.adding_a_gem_from_another_vault,
       [VaultedProject::VAULTED_GEM, VaultedProject::SECOND_VAULT_GEM]],
  }.each do |scenario, (scenario_steps, scenario_gems)|
    context scenario do
      let(:steps) { scenario_steps }
      let(:expected_gems) { scenario_gems }

      it_behaves_like "a complete bundle"
    end
  end
end
