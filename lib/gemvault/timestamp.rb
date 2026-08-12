module Gemvault
  ##
  # The notation a vault records times in.
  #
  # A manifest is a table of whitespace-separated fields (see
  # Gemvault::ManifestText), so a stored time may not contain a space. ISO 8601
  # in UTC satisfies that, sorts lexically, and is what a reader expects.
  #
  # Legacy SQLite vaults stored <tt>"2000-01-01 00:00:00"</tt>, and
  # +gemvault upgrade+ carries those values straight into the new vault, so the
  # two known notations are accepted and everything else is refused rather than
  # written into a manifest it would corrupt.
  module Timestamp
    # Raised when a value is in no notation a vault can store.
    class Error < StandardError; end

    FORMAT = "%Y-%m-%dT%H:%M:%SZ".freeze

    # What FORMAT produces: 2026-08-12T16:05:55Z.
    CANONICAL = /\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\z/

    # What Dbvault wrote: the same instant with a space for the T and no zone.
    LEGACY = /\A(\d{4}-\d\d-\d\d) (\d\d:\d\d:\d\d)\z/

    module_function

    # This instant, in the vault's notation.
    def now = Time.now.utc.strftime(FORMAT)

    # :call-seq:
    #   canonical(value) -> String
    #
    # +value+ in the vault's notation, converting a legacy vault's notation on
    # the way. Raises Error for anything else.
    def canonical(value)
      text = value.to_s
      return text if CANONICAL.match?(text)

      legacy = LEGACY.match(text)
      raise Error, "Not a time a vault can store: #{text.inspect}" unless legacy

      "#{legacy[1]}T#{legacy[2]}Z"
    end
  end
end
