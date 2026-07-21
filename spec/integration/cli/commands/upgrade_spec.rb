RSpec.describe "gemvault upgrade", :integration do
  it "converts a Dbvault into a Tarvault", :aggregate_failures do
    output, status = run_upgrade(followup: "tar -tf $V")
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("Upgraded")
    expect(output).to include("manifest.json")
    expect(output).to include("foo-1.0.0.gem")
  end

  it "preserves all gems", :aggregate_failures do
    output, status = run_upgrade(followup: "gemvault list $V")
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("foo-1.0.0")
    expect(output).to include("bar-2.0.0")
  end

  it "writes a .bak backup by default", :aggregate_failures do
    output, status = run_upgrade(followup: "ls $WORKDIR")
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("test.gemv.bak")
  end

  it "leaves the vault untouched under --dry-run", :aggregate_failures do
    output, status = run_upgrade(upgrade_args: "--dry-run", followup: "head -c15 $V")
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("Would upgrade")
    expect(output).to include("SQLite format")
  end

  it "is a no-op on an already-current Tarvault", :aggregate_failures do
    output, status = run_upgrade_on_tarvault(gems: [["foo", "1.0.0"]])
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("already current")
  end
end
