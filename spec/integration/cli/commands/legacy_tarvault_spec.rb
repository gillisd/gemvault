RSpec.describe "a vault written by an older gemvault", :integration do
  it "lists it but warns that the format is read-only" do
    expect(run_on_legacy_tarvault(command: "gemvault list $V"))
      .to succeed_showing("foo-1.0.0", "bar-2.0.0", "gemvault upgrade")
  end

  it "refuses to add to it" do
    expect(run_on_legacy_tarvault(command: "gemvault add $V $NEW_GEM"))
      .to fail_showing(/read-only|upgrade/i)
  end

  it "extracts a gem from it" do
    expect(run_on_legacy_tarvault(command: "gemvault extract $V foo --output $WORKDIR/out && ls $WORKDIR/out"))
      .to succeed_showing("foo-1.0.0.gem")
  end

  it "upgrades it to the current format" do
    expect(run_on_legacy_tarvault(command: "gemvault upgrade $V && tar -tf $V"))
      .to succeed_showing("Upgraded", "manifest", "foo-1.0.0.gem", "bar-2.0.0.gem")
  end

  it "leaves the upgraded vault writable and listable" do
    command = "gemvault upgrade $V >/dev/null && gemvault add $V $NEW_GEM && gemvault list $V"
    expect(run_on_legacy_tarvault(command:))
      .to succeed_showing("foo-1.0.0", "newcomer-1.0.0").without("read-only")
  end
end
