require 'gem_fetcher/remote_source'
require 'gem_fetcher/chunk_importer'

module GemFetcher

  class Controller

    attr_reader :config
    attr_reader :pool
    attr_reader :remote_gems

    def initialize(config)
      @config = config
      @remote_gems = RemoteSource.new(config)
    end

    def chunk_size
      100
    end

    def next_chunk
      # TODO: remove list of gems we already have
      remote_gems.list[0...chunk_size]
    end

    def run
      importer = ChunkImporter.new(next_chunk)
      importer.stage
      importer.import
    end

  end
end

