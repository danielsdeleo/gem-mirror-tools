
module GemFetcher
  class Config

    def initialize
      @staging_dir = @production_dir = nil
    end

    attr_reader :staging_dir
    attr_reader :production_dir

    def staging_dir=(staging_dir)
      @staging_dir = File.expand_path(staging_dir)
    end

    def production_dir=(production_dir)
      @production_dir = File.expand_path(production_dir)
    end
  end

  def self.config
    @config ||= Config.new
  end

  def self.configure
    yield config
  end
end

