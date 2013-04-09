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
      @chunk_index = 0
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
      chunk
    end

    def run
      until (chunk = next_chunk).empty?
        importer = ChunkImporter.new(chunk)
        importer.import
      end
    end

  end
end

