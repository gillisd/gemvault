require "gemvault/vault"

##
# A source backed by a .gemv vault file (SQLite archive of .gem blobs).
#
# Used by the gemvault RubyGems plugin to support:
#
#   gem install --source myvault.gemv activesupport

class Gem::Source::Vault < Gem::Source
  include Gem::UserInteraction

  attr_reader :path

  def initialize(path)
    path = path.to_s.sub(%r{^(?:file|vault)://}, "")
    @path = File.expand_path(path)
    @uri  = @path
    @specs = nil
  end

  def load_specs(type)
    verbose "Loading #{type} specs from vault at #{@path}"
    ensure_specs_loaded

    case type
    when :released
      @specs.keys.reject { |t| t.version.prerelease? }
    when :prerelease
      @specs.keys.select { |t| t.version.prerelease? }
    when :latest
      @specs.keys
            .group_by { |tuple| [tuple.name, tuple.platform] }
            .values
            .map { |tuples| tuples.max_by(&:version) }
    else
      @specs.keys
    end
  end

  def fetch_spec(name_tuple)
    ensure_specs_loaded

    spec = @specs[name_tuple]
    raise Gem::Exception, "Unable to find '#{name_tuple}'" unless spec

    spec
  end

  def download(spec, dir = Dir.pwd)
    verbose "Extracting #{spec.file_name} from vault at #{@path}"
    cache_dir = File.join(dir, "cache")
    FileUtils.mkdir_p(cache_dir)

    dest = File.join(cache_dir, spec.file_name)

    Gemvault::Vault.open(@path) do |vault|
      data = vault.gem_data(spec.name, spec.version.to_s, platform: spec.platform.to_s)
      File.binwrite(dest, data)
    end

    dest
  end

  def dependency_resolver_set(prerelease = false)
    require_relative "../resolver/vault_set"
    set = Gem::Resolver::VaultSet.new(self)
    set.prerelease = prerelease
    set
  end

  def <=>(other)
    case other
    when Gem::Source::Installed,
         Gem::Source::Lock then
      -1
    when Gem::Source::Vault
      0
    when Gem::Source::Local
      -1
    when Gem::Source
      1
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

  def pretty_print(q)
    q.object_group(self) do
      q.group 2, "[Vault:", "]" do
        q.breakable
        q.text @path
      end
    end
  end

  private

  def ensure_specs_loaded
    return if @specs

    @specs = {}
    Gemvault::Vault.open(@path) do |vault|
      vault.gem_entries.each do |entry|
        spec = vault.spec_from_blob(entry.name, entry.version, entry.platform)
        tuple = spec.name_tuple
        @specs[tuple] = spec
      end
    end
  end
end
