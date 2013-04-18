require 'fileutils'
require 'gem_fetcher/config'
require 'gem_fetcher/remote_source'
require 'gem_fetcher/chunk_importer'
require 'gem_fetcher/spec_indexes'

module GemFetcher

  class Controller

    attr_reader :pool
    attr_reader :spec_indexes

    def initialize()
      @remote_gems = nil
      @chunk_index = 0
      @spec_indexes = SpecIndexes.new
    end

    def remote_gems
      @remote_gems ||= RemoteSource.new(config)
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

    def config_file_path
      File.expand_path("../../../config/fetcher.rb", __FILE__)
    end

    def load_config
      if !File.exist?(config_file_path)
        $stderr.puts "no config file found at #{config_file_path}"
        $stderr.puts "You can copy the example config in that directory to get started."
      end
      TOPLEVEL_BINDING.eval(IO.read(config_file_path))
    end

    def config
      GemFetcher.config
    end

    def create_paths
      FileUtils.mkdir_p config.staging_dir
      FileUtils.mkdir_p config.production_dir
    end

    def setup
      load_config
      create_paths
    end

    def import_new_gems
      until (chunk = next_chunk).empty?
        importer = ChunkImporter.new(spec_indexes, chunk)
        importer.import
      end
    end

    def run
      setup
      import_new_gems
    end

  end
end

