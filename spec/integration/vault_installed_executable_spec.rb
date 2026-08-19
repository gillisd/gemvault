RSpec.describe "an executable installed from a vault", :integration do
  it "runs against the project's bundle" do
    expect(run_installed_tool(after_bundling: machine_left_alone)).to succeed_showing(tool_greeting)
  end

  context "when the shim recorded in the plugin index has left the gem home" do
    it "still runs against the project's bundle" do
      expect(run_installed_tool(after_bundling: DistroRuby.ambient_shim_uninstalled))
        .to succeed_showing(tool_greeting).without(nil_plugin_source_crash)
    end
  end
end
