module Gemvault
  # Class-method mixin giving vault types a block-scoped `open` that news up
  # an instance, yields it, and guarantees `close`.
  module VaultSession
    def open(path, **opts)
      raise ArgumentError, "#{name}.open requires a block" unless block_given?

      vault = new(path, **opts)
      begin
        yield vault
      ensure
        vault.close
      end
    end
  end
end
