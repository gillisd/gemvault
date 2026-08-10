RSpec.describe "SQLite vault deprecation", :integration do
  it "lists a legacy SQLite vault but warns about the deprecation" do
    expect(run_on_dbvault(command: "gemvault list $V")).to succeed_showing("foo-1.0.0", "gemvault upgrade")
  end

  it "refuses to add to a legacy SQLite vault" do
    expect(run_on_dbvault(command: "gemvault add $V /gem/addressable-2.9.0.gem")).to fail_showing(/read-only|upgrade/i)
  end

  it "does not print the deprecation warning while upgrading" do
    expect(run_upgrade).to succeed.without("deprecated")
  end
end
