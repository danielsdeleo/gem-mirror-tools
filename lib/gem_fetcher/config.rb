
module GemFetcher
  class Config
    attr_accessor :staging_dir
    attr_accessor :production_dir
  end

  def self.config
    @config ||= Config.new
  end

  def self.configure
    yield config
  end
end

