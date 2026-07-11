module Gemvault
  # Emits deprecation notices once per unique message, to a configurable IO
  # (stderr in production). Silenceable per-block or via an environment opt-out
  # so automated pipelines that consume a legacy vault are not spammed.
  module Deprecation
    ENV_KEY = "GEMVAULT_SILENCE_DEPRECATIONS".freeze

    class << self
      attr_writer :output

      def output
        @output ||= $stderr
      end

      def warn_once(message)
        return if silenced? || seen.include?(message)

        seen << message
        output.puts("gemvault: #{message}")
      end

      def silence
        previous = @silenced
        @silenced = true
        yield
      ensure
        @silenced = previous
      end

      def silenced?
        @silenced || ENV.key?(ENV_KEY)
      end

      def reset!
        @seen = []
        @silenced = false
      end

      private

      def seen
        @seen ||= []
      end
    end
  end
end
