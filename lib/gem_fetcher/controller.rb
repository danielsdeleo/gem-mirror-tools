require 'gem_fetcher/remote_source'
require 'gem_fetcher/chunk_importer'
require 'gem_fetcher/spec_indexes'

module GemFetcher

  class Controller

    attr_reader :config
    attr_reader :pool
    attr_reader :remote_gems
    attr_reader :spec_indexes

    def initialize(config)
      @config = config
      @remote_gems = RemoteSource.new(config)
      @chunk_index = 0
      @spec_indexes = SpecIndexes.new
    end

    def chunk_size
      100
    end

    def available_gems
      @available_gems ||= remote_gems.list
    end

    def next_chunk
      chunk = available_gems[@chunk_index, chunk_size]
      @chunk_index += chunk_size
      chunk || [] # Array#[] returns nil when you fall off the end
    end

    def run
      until (chunk = next_chunk).empty?
        importer = ChunkImporter.new(spec_indexes, chunk)
        importer.import
      end
    end

  end
end

