RSpec.describe "SQLite vault deprecation", :integration do
  it "lists a legacy SQLite vault but warns about the deprecation", :aggregate_failures do
    output, status = run_on_dbvault(gems: [["foo", "1.0.0"]], command: "gemvault list $V")
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("foo-1.0.0")
    expect(output).to include("gemvault upgrade")
  end

  it "refuses to add to a legacy SQLite vault", :aggregate_failures do
    gem_path = "$WORKDIR/gems/foo/foo-1.0.0.gem"
    output, status = run_on_dbvault(gems: [["foo", "1.0.0"]], command: "gemvault add $V #{gem_path}")
    expect(status).not_to be_success
    expect(output).to match(/read-only|upgrade/i)
  end

  it "does not print the deprecation warning while upgrading", :aggregate_failures do
    output, status = run_upgrade(gems: [["foo", "1.0.0"]])
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).not_to include("deprecated")
  end
end
