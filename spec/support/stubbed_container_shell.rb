RSpec.shared_context "with a stubbed container shell" do
  subject(:image) do
    ContainerImage.new(name: image_name, root: "/src/root", digest: "abc123", shell:, log:)
  end

  let(:image_name) { "gemvault-test:latest" }
  let(:shell) { instance_double(Shell) }
  let(:log) { StringIO.new }

  let(:build_command) do
    ["podman", "build", "--network=host", "-v", "/src/root:/src:ro,z",
     "--build-arg", "SOURCE_DIGEST=abc123",
     "-t", "gemvault-test:latest", "-f", "Dockerfile.test", "."]
  end

  def shell_runs(*results)
    allow(shell).to receive(:run).and_return(*results)
  end
end
