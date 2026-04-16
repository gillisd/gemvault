require_relative "spec_helper"

RSpec.describe "bundler/inline with vault source" do
  before do
    install_gemvault!
    @workdir = Pathname(Dir.mktmpdir("bundler_inline_spec"))
    @gem_build_dir = @workdir / "gems"
    @gem_build_dir.mkpath
  end

  after { @workdir.rmtree }

  it "discovers the vault plugin and installs the gem" do
    gem_path = build_gem("inline_gem", "1.0.0", dir: @gem_build_dir,
      files: {"lib/inline_gem.rb" => 'module InlineGem; VERSION = "1.0.0"; end'})

    vault_path = create_vault(@workdir / "inline.gemv", gem_path)

    script = <<~RUBY
      require "bundler/inline"

      gemfile(true) do
        source "#{vault_path}", type: :vault do
          gem "inline_gem"
        end
      end

      require "inline_gem"
      puts InlineGem::VERSION
    RUBY

    script_path = @workdir / "inline_test.rb"
    script_path.write(script)

    output, status = Open3.capture2e("ruby", script_path.to_s, chdir: @workdir.to_s)
    expect(status).to be_success
    expect(output).to match(/1\.0\.0/)
  end
end
