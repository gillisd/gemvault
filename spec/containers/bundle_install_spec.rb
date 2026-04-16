require_relative "spec_helper"

RSpec.describe "bundle install with vault source" do
  before do
    install_gemvault!
    @workdir = Pathname(Dir.mktmpdir("bundle_install_spec"))
    @gem_build_dir = @workdir / "gems"
    @gem_build_dir.mkpath
  end

  after { @workdir.rmtree }

  def write_gemfile(content)
    (@workdir / "Gemfile").write(content)
  end

  def bundle_list
    output, _status = run_bundle!("list", chdir: @workdir)
    output
  end

  it "installs a gem and makes it loadable" do
    gem_path = build_gem("hello", "1.0.0", dir: @gem_build_dir,
      files: {"lib/hello.rb" => 'module Hello; VERSION = "1.0.0"; end'})
    vault_path = create_vault(@workdir / "test.gemv", gem_path)

    write_gemfile(<<~GEMFILE)
      source "#{vault_path}", type: :vault do
        gem "hello"
      end
    GEMFILE

    output, _status = run_bundle!("install", chdir: @workdir)
    expect(output).to match(/Bundle complete!/)

    load_output, load_status = run_bundle("exec", "ruby", "-e",
      'require "hello"; puts Hello::VERSION', chdir: @workdir)
    expect(load_status).to be_success
    expect(load_output).to match(/1\.0\.0/)
  end

  it "installs multiple gems from one vault" do
    gem1 = build_gem("alpha_vault", "1.0.0", dir: @gem_build_dir)
    gem2 = build_gem("beta_vault", "2.0.0", dir: @gem_build_dir / "b")
    gem3 = build_gem("gamma_vault", "3.0.0", dir: @gem_build_dir / "c")

    vault_path = create_vault(@workdir / "multi.gemv", gem1, gem2, gem3)

    write_gemfile(<<~GEMFILE)
      source "#{vault_path}", type: :vault do
        gem "alpha_vault"
        gem "beta_vault"
        gem "gamma_vault"
      end
    GEMFILE

    run_bundle!("install", chdir: @workdir)

    listing = bundle_list
    expect(listing).to include("alpha_vault (1.0.0)")
    expect(listing).to include("beta_vault (2.0.0)")
    expect(listing).to include("gamma_vault (3.0.0)")
  end

  it "writes a correct lockfile" do
    gem_path = build_gem("locktest", "1.0.0", dir: @gem_build_dir)
    vault_path = create_vault(@workdir / "lock.gemv", gem_path)

    write_gemfile(<<~GEMFILE)
      source "#{vault_path}", type: :vault do
        gem "locktest"
      end
    GEMFILE

    run_bundle!("install", chdir: @workdir)

    lockfile = (@workdir / "Gemfile.lock").read
    expect(lockfile).to include("PLUGIN SOURCE")
    expect(lockfile).to include("type: vault")
    expect(lockfile).to include("locktest (1.0.0)")
  end

  it "produces an idempotent lockfile" do
    gem_path = build_gem("roundtrip", "1.0.0", dir: @gem_build_dir)
    vault_path = create_vault(@workdir / "rt.gemv", gem_path)

    write_gemfile(<<~GEMFILE)
      source "#{vault_path}", type: :vault do
        gem "roundtrip"
      end
    GEMFILE

    run_bundle!("install", chdir: @workdir)
    lockfile1 = (@workdir / "Gemfile.lock").read

    run_bundle!("install", chdir: @workdir)
    lockfile2 = (@workdir / "Gemfile.lock").read

    expect(lockfile2).to eq(lockfile1)
  end

  it "works alongside a rubygems.org source" do
    gem_path = build_gem("vaultgem", "1.0.0", dir: @gem_build_dir)
    vault_path = create_vault(@workdir / "mixed.gemv", gem_path)

    write_gemfile(<<~GEMFILE)
      source "https://rubygems.org"

      source "#{vault_path}", type: :vault do
        gem "vaultgem"
      end
    GEMFILE

    output, status = run_bundle("install", chdir: @workdir)
    expect(status).to be_success
    expect(output).to match(/Bundle complete!/)
  end

  it "installs only requested gems from a vault" do
    gem1 = build_gem("want1", "1.0.0", dir: @gem_build_dir)
    gem2 = build_gem("want2", "1.0.0", dir: @gem_build_dir / "w2")
    gem3 = build_gem("skipme", "1.0.0", dir: @gem_build_dir / "sk")

    vault_path = create_vault(@workdir / "subset.gemv", gem1, gem2, gem3)

    write_gemfile(<<~GEMFILE)
      source "#{vault_path}", type: :vault do
        gem "want1"
        gem "want2"
      end
    GEMFILE

    run_bundle!("install", chdir: @workdir)

    listing = bundle_list
    expect(listing).to include("want1")
    expect(listing).to include("want2")
    expect(listing).not_to include("skipme")
  end

  it "resolves intra-vault dependencies" do
    gem_b = build_gem("depb", "1.0.0", dir: @gem_build_dir / "b")
    gem_a = build_gem("depa", "1.0.0", dir: @gem_build_dir,
      files: {"lib/depa.rb" => "require 'depb'; module Depa; end"},
      dependencies: [["depb", "~> 1.0"]])

    vault_path = create_vault(@workdir / "deps.gemv", gem_a, gem_b)

    write_gemfile(<<~GEMFILE)
      source "#{vault_path}", type: :vault do
        gem "depa"
        gem "depb"
      end
    GEMFILE

    output, status = run_bundle("install", chdir: @workdir)
    expect(status).to be_success

    listing = bundle_list
    expect(listing).to include("depa (1.0.0)")
    expect(listing).to include("depb (1.0.0)")
  end

  it "picks the correct version with a constraint" do
    gem_v1 = build_gem("multiver", "1.0.0", dir: @gem_build_dir / "v1",
      files: {"lib/multiver.rb" => 'module Multiver; VERSION = "1.0.0"; end'})
    gem_v2 = build_gem("multiver", "2.0.0", dir: @gem_build_dir / "v2",
      files: {"lib/multiver.rb" => 'module Multiver; VERSION = "2.0.0"; end'})

    vault_path = create_vault(@workdir / "mv.gemv", gem_v1, gem_v2)

    write_gemfile(<<~GEMFILE)
      source "#{vault_path}", type: :vault do
        gem "multiver", "~> 2.0"
      end
    GEMFILE

    run_bundle!("install", chdir: @workdir)

    output, status = run_bundle("exec", "ruby", "-e",
      "require 'multiver'; puts Multiver::VERSION", chdir: @workdir)
    expect(status).to be_success
    expect(output).to match(/2\.0\.0/)

    listing = bundle_list
    expect(listing).to include("multiver (2.0.0)")
    expect(listing).not_to include("multiver (1.0.0)")
  end

  context "when a version constraint cannot be satisfied" do
    it "fails with a meaningful error" do
      gem_path = build_gem("constrained", "1.0.0", dir: @gem_build_dir)
      vault_path = create_vault(@workdir / "constraint.gemv", gem_path)

      write_gemfile(<<~GEMFILE)
        source "#{vault_path}", type: :vault do
          gem "constrained", "~> 2.0"
        end
      GEMFILE

      output, status = run_bundle("install", chdir: @workdir)
      expect(status).not_to be_success
      expect(output).to match(/could not find/i)
    end
  end
end
