RSpec.describe Podman do
  describe ".command" do
    it "invokes podman" do
      expect(described_class.command("run", env: {}).first).to eq("podman")
    end

    it "keeps the arguments in the order given" do
      expect(described_class.command("run", "--rm", "img", env: {})).to eq(["podman", "run", "--rm", "img"])
    end

    it "adds no runtime flag when the variable is unset" do
      expect(described_class.command("build", env: {})).to eq(["podman", "build"])
    end

    it "adds no runtime flag when the variable is empty" do
      expect(described_class.command("build", env: { "GEMVAULT_PODMAN_RUNTIME" => "" })).to eq(["podman", "build"])
    end

    context "when the variable names a runtime" do
      let(:env) { { "GEMVAULT_PODMAN_RUNTIME" => "/usr/local/bin/crun-pinned" } }

      it "pins it" do
        expect(described_class.command("build", env: env))
          .to eq(["podman", "--runtime", "/usr/local/bin/crun-pinned", "build"])
      end

      it "pins it before the subcommand" do
        pinned = described_class.command("run", "--rm", env: env)
        expect(pinned.index("--runtime")).to be < pinned.index("run")
      end
    end
  end
end
