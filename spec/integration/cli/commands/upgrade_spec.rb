RSpec.describe "gemvault upgrade", :integration do
  it "converts a Dbvault into a Tarvault" do
    expect(run_upgrade(followup: "tar -tf $V")).to succeed_showing("Upgraded", "manifest", "foo-1.0.0.gem")
  end

  it "preserves all gems" do
    expect(run_upgrade(followup: "gemvault list $V")).to succeed_showing("foo-1.0.0", "bar-2.0.0")
  end

  it "writes a .bak backup by default" do
    expect(run_upgrade(followup: "ls $WORKDIR")).to succeed_showing("test.gemv.bak")
  end

  it "leaves the vault untouched under --dry-run" do
    expect(run_upgrade(upgrade_args: "--dry-run", followup: "head -c15 $V"))
      .to succeed_showing("Would upgrade", "SQLite format")
  end

  it "is a no-op on an already-current Tarvault" do
    expect(run_upgrade_on_tarvault(gems: [["foo", "1.0.0"]])).to succeed_showing("already current")
  end
end
