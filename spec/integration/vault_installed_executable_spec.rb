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

  context "when the project directory was moved after bundling" do
    it "dies inside bundler rather than running" do
      expect(run_relocated_tool(after_moving: machine_left_alone)).to fail_showing(nil_plugin_source_crash)
    end

    context "when the doctor is run after the failure" do
      it "runs against the project's bundle" do
        expect(run_relocated_tool(after_moving: doctor_after_the_crash)).to succeed_showing(tool_greeting)
      end
    end
  end
end
