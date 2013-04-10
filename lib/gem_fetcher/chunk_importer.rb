
module GemFetcher

  # Imports a "chunk" of gems from a staging location to the
  # "production" gem repo dir.
  class ChunkImporter

    attr_reader :gems
    attr_reader :pool
    attr_reader :spec_indexes

    def initialize(spec_indexes, gems)
      @spec_indexes = spec_indexes
      @gems = gems
      @pool = Pool.new(10)

      @new_gems = nil
    end

    def config
      GemFetcher.config
    end

    def base_dir
      config.production_dir
    end

    def gem_dir
      @gem_dir ||= File.join(base_dir, "gems")
    end

    def quick_marshal_dir
      @quick_marshal_dir ||= File.join(base_dir, "quick/Marshal.4.8")
    end

    def new_gems
      if @new_gems.nil?
        @new_gems = []
        gems.each do |gem|
          if spec_indexes.include?(gem)
            debug "skipping gem #{gem.name} #{gem.version} (#{gem.platform})"
          else
            @new_gems << gem
          end
        end
        @new_gems.reverse!
      end
      @new_gems
    end

    def import
      if new_gems.empty?
        log "no new gems in chunk"
        return
      end

      stage_gems
      import_staged_gems
      update_spec_indexes

      # require 'pp'
      # pp :released => released_specs_index
      # pp :prerelease => prerelease_specs_index
      # pp :latest => latest_specs_index
      log "Imported #{new_gems.size} gems"
      log "Release gems: #{released_specs_index.size}"
      log "Prerelease:   #{prerelease_specs_index.size}"
      log "Latest gems:  #{latest_specs_index.size}"

      cleanup_refs!
    end

    def cleanup_refs!
      @gems = nil
      @new_gems = nil
      @pool = nil
      GC.start
    end

    def stage_gems
      new_gems.each do |gem|
        pool.job do
          gem.stage
        end
      end
      pool.run_til_done
    end

    def import_staged_gems
      new_gems.each do |gem|
        gem.import_gem
        gem.import_quick_marshal
        add_gem_to_indexes(gem)
      end
    end

    def update_spec_indexes
      spec_indexes.commit_changes
    end

    def add_gem_to_indexes(gem)
      spec_indexes.add_gem(gem)
    end

    def path_to_gem(file_name)
      intermediate_dir1 = file_name[0...2]
      intermediate_dir2 = file_name[0...4]
      File.join(gem_base_dir, intermediate_dir1, intermediate_dir2, file_name)
    end

    def released_specs_index
      spec_indexes.released_specs_index
    end

    def latest_specs_index
      spec_indexes.latest_specs_index
    end

    def prerelease_specs_index
      spec_indexes.prerelease_specs_index
    end

    def log(string)
      $stdout.print("#{string}\n")
    end

    def debug(string)
      $stdout.print("#{string}\n") if ENV["DEBUG"]
    end

  end
end

