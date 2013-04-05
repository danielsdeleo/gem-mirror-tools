require 'gem_fetcher/gem_mover'

module GemFetcher
  class RemoteSource


    class Error < StandardError
    end

    attr_reader :config
    attr_reader :fetcher

    def initialize(config)
      @config = config
      @fetcher = Fetcher.new
    end

    def list
      gem_tuples = Marshal.load(marshaled_remote_spec_list)
      gem_tuples.map do |tuple|
        GemMover.new(tuple)
      end
    end

    def marshaled_remote_spec_list
      compressed = StringIO.new(compressed_remote_spec_list)
      Zlib::GzipReader.new(compressed).read
    end

    def compressed_remote_spec_list
      fetcher.fetch(remote_spec_list_uri)
    end

    def remote_spec_list_uri
      "https://rubygems.org/specs.4.8.gz"
    end

  end
end

