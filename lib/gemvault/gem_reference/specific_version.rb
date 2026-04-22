module Gemvault
  module GemReference
    # Matches one exact version of a named gem in the vault. `version:` is
    # always a Gem::Version `.parse` validates and constructs it before
    # calling .new.
    SpecificVersion = Data.define(:name, :version).freeze
  end
end
