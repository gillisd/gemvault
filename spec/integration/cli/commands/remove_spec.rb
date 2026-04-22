RSpec.describe "gemvault remove", :integration do
  def remove_script(gems:, remove_args:, followup: "")
    preamble = FixtureScript.preamble(gems: gems)
    <<~SH
      #{preamble}
      gemvault remove $WORKDIR/test.gemv #{remove_args}
      #{followup}
    SH
  end

  it "removes via a combined NAME-VERSION argument" do
    output, status = podman_run(remove_script(
      gems: [["foo", "1.0.0"]],
      remove_args: "foo-1.0.0",
    ))
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to match(/Removed 1 gem/)
  end

  it "removes via a positional VERSION argument" do
    output, status = podman_run(remove_script(
      gems: [["foo", "1.0.0"]],
      remove_args: "foo 1.0.0",
    ))
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to match(/Removed 1 gem/)
  end

  it "removes via the --version option" do
    output, status = podman_run(remove_script(
      gems: [["foo", "1.0.0"]],
      remove_args: "foo --version 1.0.0",
    ))
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to match(/Removed 1 gem/)
  end

  it "removes via the -v short option" do
    output, status = podman_run(remove_script(
      gems: [["foo", "1.0.0"]],
      remove_args: "foo -v 1.0.0",
    ))
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to match(/Removed 1 gem/)
  end

  it "preserves hyphenated names in the combined form" do
    output, status = podman_run(remove_script(
      gems: [["foo-bar", "2.3.4"]],
      remove_args: "foo-bar-2.3.4",
    ))
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to match(/Removed 1 gem/)
  end

  it "lets --version override the embedded version in NAME-VERSION" do
    output, status = podman_run(remove_script(
      gems: [["foo", "1.0.0"], ["foo", "2.0.0"]],
      remove_args: "foo-1.0.0 --version 2.0.0",
      followup: "gemvault list $WORKDIR/test.gemv",
    ))
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to match(/Removed 1 gem/)
    expect(output).to match(/^foo-1\.0\.0$/)
    expect(output).not_to match(/^foo-2\.0\.0$/)
  end

  it "rejects a ranged version requirement" do
    output, status = podman_run(remove_script(
      gems: [["foo", "1.0.0"]],
      remove_args: "foo --version '~> 1.0'",
    ))
    expect(status).not_to be_success
    expect(output).to match(/exact version/i)
  end
end
