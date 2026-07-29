RSpec.describe "plugins.rb preamble", :integration do
  let(:result) { run_plugin_root_probe }
  let(:probe_output) { result.first }
  let(:probe_status) { result.last }

  it "makes Plugin.root gem specs discoverable by RubyGems" do
    expect(probe_output).to include("PASS")
  end

  it "finishes without an error" do
    expect(probe_status).to be_success, probe_output
  end
end
