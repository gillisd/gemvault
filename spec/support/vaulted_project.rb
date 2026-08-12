module VaultedProject
  VAULTED_GEM = "vaulted_gem".freeze
  COMPANION_VAULTED_GEM = "companion_vaulted_gem".freeze
  SECOND_VAULT_GEM = "second_vault_gem".freeze
  RUBYGEMS_GEM = "command_kit".freeze
  OWN_GEM = "the_project_itself".freeze
  OWN_GEM_CONSTANT = "TheProjectItself".freeze

  SECOND_VAULT = "second".freeze
  CHOSEN_INSTALL_PATH = ".gems/ruby-bundle".freeze

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

  def self.newer_gemvault_left_behind
    DistroRuby.newer_gemvault_alongside
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

  # cache_all matches the reporter's own .bundle/config, and is what makes
  # `bundle cache` take path and git sources too rather than rubygems alone.
  def self.gems_cached
    <<~SH
      bundle config set cache_all true
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
    reinstall_with(VaultedGemfile.declaring)
  end

  def self.adding_a_gem_from_rubygems
    reinstall_with(VaultedGemfile.declaring(vaulted: [VAULTED_GEM], rubygems: [RUBYGEMS_GEM]))
  end

  def self.adding_the_projects_own_gemspec
    reinstall_with(VaultedGemfile.declaring(vaulted: [VAULTED_GEM], own_gemspec: true))
  end

  def self.adding_another_gem_from_the_same_vault
    reinstall_with(VaultedGemfile.declaring(vaulted: [VAULTED_GEM, COMPANION_VAULTED_GEM]))
  end

  def self.adding_a_gem_from_another_vault
    reinstall_with(VaultedGemfile.declaring(vaulted: [VAULTED_GEM], second_vault: [SECOND_VAULT_GEM]))
  end

  def self.running_the_doctor
    <<~SH
      gemvault doctor
      bundle install
    SH
  end

  # The reporter's own flow for issue #23: bundle install fails, then the
  # doctor is asked to repair the machine, and the scenario's closing install
  # confirms the recovery. The guard exit aborts if the first install
  # unexpectedly succeeds, so the doctor is only ever credited with a recovery
  # it actually performed.
  def self.recovering_with_the_doctor
    <<~SH
      bundle install && exit 90
      gemvault doctor
    SH
  end

  def self.reinstall_with(gemfile)
    "#{gemfile}bundle install\n"
  end
end
