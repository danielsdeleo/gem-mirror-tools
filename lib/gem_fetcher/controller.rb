require 'gem_fetcher/remote_source'

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
      stager = Stager.new(config.staging_dir, next_chunk)
      stager.stage_gems
    end

  end
end

