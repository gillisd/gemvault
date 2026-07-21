module PluginInstallScenarios
  def install_plugin_in_project_with_vendor_path
    podman_run(<<~SH)
      #{GemIndex.serve_preamble}
      #{GemIndex.gemrc_pointing_at_index}
      #{project_with_vendor_path}
      bundle plugin install bundler-source-vault
    SH
  end

  def install_plugin_outside_any_project
    podman_run(<<~SH)
      #{GemIndex.serve_preamble}
      #{GemIndex.gemrc_pointing_at_index}
      mkdir -p /work/nowhere && cd /work/nowhere
      bundle plugin install bundler-source-vault
      bundle plugin list
    SH
  end

  def install_plugin_with_distro_bundler
    podman_run(<<~SH)
      #{GemIndex.serve_preamble}
      #{GemIndex.gemrc_pointing_at_index}
      #{DistroRuby.regular_bundler}
      #{project_with_vendor_path}
      bundle plugin install bundler-source-vault
    SH
  end

  private

  def project_with_vendor_path
    <<~SH
      mkdir -p /work/app && cd /work/app
      echo 'source "http://127.0.0.1:#{GemIndex::PORT}"' > Gemfile
      bundle config set --local path vendor >/dev/null
    SH
  end
end

RSpec.configure do |config|
  config.include PluginInstallScenarios, :integration
end
