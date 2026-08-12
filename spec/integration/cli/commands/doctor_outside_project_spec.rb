RSpec.describe "gemvault doctor outside any project", :integration do
  it "succeeds" do
    output, status = run_doctor_outside_any_project
    expect(status).to be_success, "Failed:\n#{output}"
  end

  it "still uninstalls the plugin from bundler's global index" do
    output, = run_doctor_outside_any_project
    expect(output).to include("bundler-source-vault")
  end

  it "does not claim to have cleared a project index" do
    output, = run_doctor_outside_any_project
    expect(output).not_to include("plugin index at")
  end

  it "does not dump bundler's usage screen" do
    output, = run_doctor_outside_any_project
    expect(output).not_to include("bundle binstubs GEM")
  end

  it "points at the project directory to reinstall" do
    output, = run_doctor_outside_any_project
    expect(output).to include("project directory")
  end
end
