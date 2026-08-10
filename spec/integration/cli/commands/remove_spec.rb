RSpec.describe "gemvault remove", :integration do
  def removal(args)
    run_remove(gems: [["foo", "1.0.0"]], remove_args: args)
  end

  it "removes via a combined NAME-VERSION argument" do
    expect(removal("foo-1.0.0")).to succeed_showing("Removed 1 gem")
  end

  it "removes via a positional VERSION argument" do
    expect(removal("foo 1.0.0")).to succeed_showing("Removed 1 gem")
  end

  it "removes via the --version option" do
    expect(removal("foo --version 1.0.0")).to succeed_showing("Removed 1 gem")
  end

  it "removes via the -v short option" do
    expect(removal("foo -v 1.0.0")).to succeed_showing("Removed 1 gem")
  end

  it "preserves hyphenated names in the combined form" do
    expect(run_remove(gems: [["foo-bar", "2.3.4"]], remove_args: "foo-bar-2.3.4"))
      .to succeed_showing("Removed 1 gem")
  end

  it "lets --version override the embedded version in NAME-VERSION" do
    expect(remove_with_version_override)
      .to succeed_showing("Removed 1 gem", /^foo-1\.0\.0$/).without(/^foo-2\.0\.0$/)
  end

  it "rejects a ranged version requirement" do
    expect(removal("foo --version '~> 1.0'")).to fail_showing(/exact version/i)
  end
end
