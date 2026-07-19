require "gemvault/vault"
require "gemvault/vault_path"
require "gemvault/gem_entry"
require "pathname"

##
# A source backed by a .gemv vault file: a tar archive of .gem files indexed
# by a manifest. Legacy SQLite vaults are read transparently.
#
# Used by the gemvault RubyGems plugin to support:
#
#   gem install --source myvault.gemv activesupport
class Gem::Source::Vault < Gem::Source
  include Gem::UserInteraction

  attr_reader :path

  def initialize(path)
    resolved = Gemvault::VaultPath.resolve(path)
    @path = Pathname(resolved).expand_path.to_s
    super(@path)
    @uri = @path
    @specs = nil
  end

  def load_specs(type)
    verbose "Loading #{type} specs from vault at #{@path}"
    ensure_specs_loaded
    select_candidates(type)
  end

  def fetch_spec(name_tuple)
    ensure_specs_loaded

    spec = @specs[name_tuple]
    raise Gem::Exception, "Unable to find '#{name_tuple}'" unless spec

    spec
  end

  def download(spec, dir = Dir.pwd)
    verbose "Extracting #{spec.file_name} from vault at #{@path}"
    dest = Pathname(dir).join("cache").tap(&:mkpath).join(spec.file_name)

    Gemvault::Vault.open(@path) do |vault|
      entry = entry_for(spec)
      bytes = vault.gem_data(entry)
      dest.binwrite(bytes)
    end

    dest.to_s
  end

  def dependency_resolver_set(prerelease = nil)
    require_relative "../resolver/vault_set"
    set = Gem::Resolver::VaultSet.new(self)
    set.prerelease = prerelease
    set
  end

  def <=>(other)
    case other
    when Gem::Source::Installed, Gem::Source::Lock, Gem::Source::Local then -1
    when Gem::Source::Vault then 0
    when Gem::Source then 1
    end
  end

  def ==(other)
    other.is_a?(self.class) && @path == other.path
  end

  alias eql? ==

  def hash
    @path.hash
  end

  def to_s
    "vault at #{@path}"
  end

  def pretty_print(pp)
    pp.object_group(self) do
      pp.group 2, "[Vault:", "]" do
        pp.breakable
        pp.text @path
      end
    end
  end

  private

  def entry_for(spec)
    Gemvault::GemEntry.from_spec(spec)
  end

  def select_candidates(type)
    case type
    when :released then released_candidates
    when :prerelease then prerelease_candidates
    when :latest then latest_candidates
    else @specs.keys
    end
  end

  def released_candidates
    @specs.keys.reject { |candidate| candidate.version.prerelease? }
  end

  def prerelease_candidates
    @specs.keys.select { |candidate| candidate.version.prerelease? }
  end

  def latest_candidates
    @specs.keys
          .group_by { |candidate| [candidate.name, candidate.platform] }
          .values
          .map { |versions| versions.max_by(&:version) }
  end

  def ensure_specs_loaded
    return if @specs

    @specs = {}
    Gemvault::Vault.open(@path) do |vault|
      vault.gem_entries.each do |entry|
        spec = vault.spec_from_blob(entry)
        @specs[spec.name_tuple] = spec
      end
    end
  end
end
