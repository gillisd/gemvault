RSpec.describe "a machine whose newest json gem is not gemvault's to rely on", :integration do
  it "lists the vault without consulting the json gem" do
    expect(bundle_exec_with_older_locked_json)
      .to succeed_showing("vault_test_gem").without("uninitialized constant JSON")
  end

  it "runs the app instead of dying on json activation" do
    expect(bundle_exec_with_older_locked_json)
      .to succeed_showing("1.0.0").without("already activated json")
  end
end
