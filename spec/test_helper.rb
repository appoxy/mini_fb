module TestHelper
  class << self
    
    def config
      @config  ||= File.open(config_path) { |yf| YAML::load(yf) }
    end

    private

      def config_path
        File.expand_path("../mini_fb_tests.yml", File.dirname(__FILE__))
      end
  end
end
