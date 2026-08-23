RSpec.shared_context "when a project bundles a gem from a vault" do
  let(:machine) { VaultedProject::STOCK_MACHINE }
  let(:setup) { VaultedProject::NOTHING_CONFIGURED }
  let(:steps) { VaultedProject::NOTHING_FURTHER }
  let(:expected_gems) { [VaultedProject::VAULTED_GEM] }
  let(:result) { install_vaulted_project(machine:, setup:, steps:) }
  let(:bundle_output) { result.first }
  let(:bundle_status) { result.last }
end
