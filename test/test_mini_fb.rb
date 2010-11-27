require 'test/unit'
require 'uri'
require 'yaml'
require 'active_support/core_ext'
require '../lib/mini_fb'

class MiniFBTests < Test::Unit::TestCase


    def setup
        @config = File.open(File.expand_path("~/.mini_fb_tests.yml")) { |yf| YAML::load(yf) }
        puts @config.inspect
        MiniFB.log_level = :debug

#        MiniFB.oauth_url(@config["fb_api_key"], @config["fb_secret"])
    end

    def teardown

    end

    def test_authenticate_as_app
        res = MiniFB.authenticate_as_app(@config["fb_api_key"], @config["fb_secret"])
        puts 'res=' + res.inspect
        assert res["access_token"].present?
        assert res["access_token"].starts_with?(@config["fb_app_id"].to_s)
    end

    # Test signature verification.
    def test_signature

    end

    def test_me_with_fields
        fields = {
                'interests' => [:name],
                'activities'=> [:name],
                'music'     => [:name],
                'videos'    => [:name],
                'television'=> [:name],
                'movies'    => [:name],
                'likes'     => [:name],
                'work'      => [:name],
                'education' => [:name],
                'books'     => [:name]
        }

        snap   = MiniFB.get(access_token, 'me', :fields =>fields.keys)
    end

    def test_basic_calls

    end

    def test_session

    end

    def test_photos

    end

    def test_uri_escape
        assert URI.escape("x=y") == "x=y"
    end

end