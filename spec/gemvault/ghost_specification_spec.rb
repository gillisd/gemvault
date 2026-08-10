require "gemvault/ghost_specification"

RSpec.describe Gemvault::GhostSpecification do
  let(:root) { gem_dir / "root" }
  let(:other_root) { gem_dir / "other_root" }

  def install_record(name, version, root: self.root, payload: true)
    file = root / "specifications" / "#{name}-#{version}.gemspec"
    file.dirname.mkpath
    file.write(<<~GEMSPEC)
      Gem::Specification.new do |s|
        s.name = #{name.inspect}
        s.version = #{version.inspect}
      end
    GEMSPEC
    (root / "gems" / "#{name}-#{version}").mkpath if payload
    file
  end

  describe ".of" do
    it "finds a specification whose gem directory is missing" do
      ghost = install_record("bundler-source-vault", "0.2.4", payload: false)

      expect(described_class.of("bundler-source-vault", roots: [root]).map(&:file)).to eq([ghost])
    end

    it "ignores a specification whose gem directory is present" do
      install_record("bundler-source-vault", "0.2.4")

      expect(described_class.of("bundler-source-vault", roots: [root])).to be_empty
    end

    it "ignores a gem whose name merely starts with the asked name" do
      install_record("gemvault-extra", "1.0.0", payload: false)

      expect(described_class.of("gemvault", roots: [root])).to be_empty
    end

    it "finds ghosts in every given root" do
      first = install_record("gemvault", "0.2.3", payload: false)
      second = install_record("gemvault", "0.2.4", root: other_root, payload: false)

      expect(described_class.of("gemvault", roots: [root, other_root]).map(&:file)).to contain_exactly(first, second)
    end

    it "is empty for a root with no specifications directory" do
      expect(described_class.of("gemvault", roots: [gem_dir / "absent"])).to be_empty
    end
  end

  describe "#delete" do
    it "removes the specification file" do
      ghost_file = install_record("gemvault", "0.2.4", payload: false)

      described_class.of("gemvault", roots: [root]).each(&:delete)

      expect(ghost_file).not_to exist
    end

    it "leaves intact installations alone" do
      install_record("gemvault", "0.2.4")
      install_record("gemvault", "0.2.3", payload: false)

      described_class.of("gemvault", roots: [root]).each(&:delete)

      expect(root / "specifications" / "gemvault-0.2.4.gemspec").to exist
    end
  end
end
