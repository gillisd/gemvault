require_relative "rubygems/source/vault"
require "rubygems/source_list"

##
# RubyGems plugin for .gemv vault sources.
#
# Enables: gem install --source myvault.gemv activesupport
#
# Three monkey-patches (via prepend) are needed because RubyGems has no
# source registration API:
#
# 1. accept_uri_http let .gemv paths bypass URI scheme validation
# 2. add_source_option skip trailing"/" append for .gemv paths
# 3. SourceList#<< route .gemv strings to Gem::Source::Vault

module Gemvault
  module AcceptVaultURI
    def accept_uri_http
      Gem::OptionParser.accept Gem::URI::HTTP do |value|
        next value if value.to_s.end_with?(".gemv")

        begin
          uri = Gem::URI.parse value
        rescue Gem::URI::InvalidURIError
          raise Gem::OptionParser::InvalidArgument, value
        end

        valid_uri_schemes = ["http", "https", "file", "s3"]
        unless valid_uri_schemes.include?(uri.scheme)
          msg = "Invalid uri scheme for #{value}\nPreface URLs with one of #{valid_uri_schemes.map { |s| "#{s}://" }}"
          raise ArgumentError, msg
        end

        value
      end
    end
  end

  module AddVaultSourceOption
    def add_source_option
      accept_uri_http

      add_option(:"Local/Remote", "-s", "--source URL", Gem::URI::HTTP,
                 "Append URL to list of remote gem sources") do |source, options|
        source << "/" unless source.end_with?("/", ".gemv")

        if options.delete :sources_cleared
          Gem.sources = [source]
        else
          Gem.sources << source unless Gem.sources.include?(source)
        end
      end
    end
  end

  module VaultSourceList
    def <<(obj)
      if obj.is_a?(String) && obj.end_with?(".gemv")
        src = Gem::Source::Vault.new(obj)
        @sources << src unless @sources.include?(src)
        return src
      end
      super
    end
  end
end

Gem::SourceList.prepend Gemvault::VaultSourceList

require "rubygems/local_remote_options"
Gem::LocalRemoteOptions.prepend Gemvault::AcceptVaultURI
Gem::LocalRemoteOptions.prepend Gemvault::AddVaultSourceOption
