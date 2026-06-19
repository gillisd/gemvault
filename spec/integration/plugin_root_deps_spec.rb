RSpec.describe "plugins.rb preamble", :integration do
  it "makes Plugin.root gem specs discoverable by RubyGems", :aggregate_failures do
    output, status = run_plugin_root_probe
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("PASS")
  end
end
