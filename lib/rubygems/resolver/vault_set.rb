# frozen_string_literal: true

##
# A VaultSet looks up specifications from a .gemv vault source.
#
# Returns standard Gem::Resolver::IndexSpecification objects so the
# resolver's install pipeline (download → Gem::Installer) works unchanged.

class Gem::Resolver::VaultSet < Gem::Resolver::Set
  def initialize(source)
    super()
    @source = source
    @specs = source.load_specs(:complete)
  end

  def find_all(req)
    @specs.select { |tuple| req.match?(tuple) }.map do |tuple|
      Gem::Resolver::IndexSpecification.new(
        self,
        tuple.name,
        tuple.version,
        @source,
        tuple.platform
      )
    end
  end

  def prefetch(reqs)
  end

  def pretty_print(q)
    q.group 2, "[VaultSet", "]" do
      next if @specs.empty?
      q.breakable

      q.seplist @specs do |tuple|
        q.text tuple.full_name
      end
    end
  end
end
