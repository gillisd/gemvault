module VaultedProject
  VAULTED_GEM = "vaulted_gem".freeze
  COMPANION_VAULTED_GEM = "companion_vaulted_gem".freeze
  SECOND_VAULT_GEM = "second_vault_gem".freeze
  RUBYGEMS_GEM = "command_kit".freeze

  SECOND_VAULT = "second".freeze
  CHOSEN_INSTALL_PATH = "vendor/bundle".freeze

  VAULT_GEMS = [[VAULTED_GEM, "1.0.0"], [COMPANION_VAULTED_GEM, "1.0.0"]].freeze
  SECOND_VAULT_GEMS = [[SECOND_VAULT_GEM, "1.0.0"]].freeze

  STOCK_MACHINE = "".freeze
  NOTHING_CONFIGURED = "".freeze
  NOTHING_FURTHER = "".freeze

  CHOSEN_PATH_CONFIRMATION = "Bundled gems are installed into `./#{CHOSEN_INSTALL_PATH}`".freeze

  # Removed after the fixture vault is built, since building it needs the CLI.
  # The image installs gemvault system-wide, so every other scenario runs with an
  # ambient copy; this is the one that makes the plugin root carry it instead.
  def self.gemvault_uninstalled
    DistroRuby.without_system_gemvault
  end

  def self.install_path_chosen
    "bundle config set path #{CHOSEN_INSTALL_PATH}\n"
  end

  def self.install_path_removed
    <<~SH
      bundle config set path #{CHOSEN_INSTALL_PATH}
      bundle install
      bundle config unset path
    SH
  end

  def self.gems_cached
    <<~SH
      bundle install
      bundle cache
    SH
  end

  def self.deleting_the_lockfile
    <<~SH
      rm -f Gemfile.lock
      bundle install
    SH
  end

  def self.deleting_the_bundle_directory
    <<~SH
      rm -rf .bundle
      bundle install
    SH
  end

  def self.deleting_the_lockfile_and_the_bundle_directory
    <<~SH
      rm -f Gemfile.lock
      rm -rf .bundle
      bundle install
    SH
  end

  def self.removing_the_vaulted_gem
    reinstall_with(gemfile_declaring)
  end

  def self.adding_a_gem_from_rubygems
    reinstall_with(gemfile_declaring(vaulted: [VAULTED_GEM], rubygems: [RUBYGEMS_GEM]))
  end

  def self.adding_another_gem_from_the_same_vault
    reinstall_with(gemfile_declaring(vaulted: [VAULTED_GEM, COMPANION_VAULTED_GEM]))
  end

  def self.adding_a_gem_from_another_vault
    reinstall_with(gemfile_declaring(vaulted: [VAULTED_GEM], second_vault: [SECOND_VAULT_GEM]))
  end

  def self.running_the_doctor
    <<~SH
      gemvault doctor
      bundle install
    SH
  end

  def self.reinstall_with(gemfile)
    "#{gemfile}bundle install\n"
  end

  def self.gemfile_declaring(vaulted: [], second_vault: [], rubygems: [])
    <<~SH
      cat > Gemfile <<GEMFILE
      #{GemIndex.source_line}
      #{rubygems.map { |name| %(gem "#{name}") }.join("\n")}
      #{vault_block("$WORKDIR/test.gemv", vaulted)}
      #{vault_block("$WORKDIR/#{SECOND_VAULT}.gemv", second_vault)}
      GEMFILE
    SH
  end

  def self.vault_block(vault, gems)
    return "" if gems.empty?

    declarations = gems.map { |name| %(  gem "#{name}") }.join("\n")

    "source \"#{vault}\", type: :vault do\n#{declarations}\nend"
  end
end
