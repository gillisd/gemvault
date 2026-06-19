##
# A VaultSet looks up specifications from a .gemv vault source.
#
# Returns standard Gem::Resolver::IndexSpecification objects so the
# resolver's install pipeline (download -> Gem::Installer) works unchanged.
class Gem::Resolver::VaultSet < Gem::Resolver::Set
  def initialize(source)
    super()
    @source = source
    @specs = source.load_specs(:complete)
  end

  def find_all(req)
    @specs.filter_map { |tuple| index_spec_for(req, tuple) }
  end

  def prefetch(reqs); end

  def pretty_print(pp)
    pp.group 2, "[VaultSet", "]" do
      next if @specs.empty?

      pp.breakable

      pp.seplist @specs do |tuple|
        pp.text tuple.full_name
      end
    end
  end

  private

  def index_spec_for(req, tuple)
    return unless req.match?(tuple)

    Gem::Resolver::IndexSpecification.new(
      self, tuple.name, tuple.version, @source, tuple.platform
    )
  end
end
