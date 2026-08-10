require "gemvault/ghost_specification"

RSpec.describe Gemvault::GhostSpecification do
  let(:root) { gem_dir / "root" }
  let(:other_root) { gem_dir / "other_root" }

  def record_body(name, version, platform)
    <<~GEMSPEC
      # -*- encoding: utf-8 -*-
      # stub: #{name} #{version} #{platform} lib

      Gem::Specification.new do |s|
        s.name = #{name.inspect}
        s.version = #{version.inspect}
        s.platform = #{platform.inspect}
      end
    GEMSPEC
  end

  def install_record(name, version, **options)
    root = options.fetch(:root, self.root)
    platform = options.fetch(:platform, "ruby")
    full_name = platform == "ruby" ? "#{name}-#{version}" : "#{name}-#{version}-#{platform}"
    file = root / "specifications" / "#{full_name}.gemspec"
    file.dirname.mkpath
    file.write(options.fetch(:body) { record_body(name, version, platform) })
    (root / "gems" / full_name).mkpath if options.fetch(:payload, true)
    file
  end

  describe ".of" do
    it "finds a record whose gem directory is missing" do
      ghost = install_record("bundler-source-vault", "0.2.4", payload: false)

      expect(described_class.of("bundler-source-vault", roots: [root]).map(&:file)).to eq([ghost])
    end

    it "ignores a record whose gem directory is present" do
      install_record("bundler-source-vault", "0.2.4")

      expect(described_class.of("bundler-source-vault", roots: [root])).to be_empty
    end

    it "ignores a gem whose name merely starts with the asked name" do
      install_record("gemvault-extra", "1.0.0", payload: false)

      expect(described_class.of("gemvault", roots: [root])).to be_empty
    end

    it "finds a ghost of a platform-suffixed release" do
      ghost = install_record("gemvault", "0.2.4", platform: "x86_64-linux", payload: false)

      expect(described_class.of("gemvault", roots: [root]).map(&:file)).to eq([ghost])
    end

    it "finds a ghost whose record is truncated wreckage" do
      ghost = install_record("gemvault", "0.2.4", payload: false, body: "# -*- encoding: utf-8 -*-\nGem::Sp")

      expect(described_class.of("gemvault", roots: [root]).map(&:file)).to eq([ghost])
    end

    it "ignores a truncated record whose gem directory is present" do
      install_record("gemvault", "0.2.4", body: "# -*- encoding: utf-8 -*-\nGem::Sp")

      expect(described_class.of("gemvault", roots: [root])).to be_empty
    end

    it "ignores a truncated record of a longer-named gem" do
      install_record("gemvault-extra", "1.0.0", payload: false, body: "Gem::Sp")

      expect(described_class.of("gemvault", roots: [root])).to be_empty
    end

    it "tolerates an unreadable neighboring record" do
      neighbor = install_record("gemvault-extra", "1.0.0", payload: false)
      neighbor.chmod(0o000)

      expect(described_class.of("gemvault", roots: [root])).to be_empty
    ensure
      neighbor.chmod(0o644)
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

  describe ".new" do
    it "is private, so every instance comes from a scan" do
      expect { described_class.new(root / "x.gemspec") }.to raise_error(NoMethodError)
    end
  end

  describe "#to_s" do
    it "is the record's path" do
      install_record("gemvault", "0.2.4", payload: false)

      expect(described_class.of("gemvault", roots: [root]).map(&:to_s))
        .to eq([(root / "specifications" / "gemvault-0.2.4.gemspec").to_s])
    end
  end

  describe "#delete" do
    it "removes the record" do
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
