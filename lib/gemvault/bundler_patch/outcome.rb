module Gemvault
  class BundlerPatch
    # The outcome of one Apply or Revert against a BundlerInstallation.
    # Each variant is its own Data class so callers pattern-match by type:
    #
    #   in Outcome::Applied        then ...
    #   in Outcome::AlreadyApplied then ...
    #
    # Construct with the bracket form:
    #
    #   Outcome::Applied[installation: bundler_installation]
    module Outcome
      Applied        = Data.define(:installation).freeze
      AlreadyApplied = Data.define(:installation).freeze
      Reverted       = Data.define(:installation).freeze
      NotApplied     = Data.define(:installation).freeze
    end
  end
end
