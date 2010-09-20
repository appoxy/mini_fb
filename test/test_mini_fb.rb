require 'test/unit'
require 'uri'
require 'yaml'
require 'active_support'
require '../lib/mini_fb'

class MiniFBTests < Test::Unit::TestCase


    def setup
        @config = File.open(File.expand_path("~/.mini_fb_tests.yml")) { |yf| YAML::load(yf) }
        puts @config.inspect
        MiniFB.log_level = :debug
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

    def test_basic_calls

    end

    def test_session

    end

    def test_photos

    end

    def test_uri_escape
        assert URI.escape("x=y") == "x=y"
    end

    def test_signed_request_params
        # Example request and secret taken from http://developers.facebook.com/docs/authentication/canvas
        secret = 'secret'
        req = 'vlXgu64BQGFSQrY0ZcJBZASMvYvTHu9GQ0YM9rjPSso.eyJhbGdvcml0aG0iOiJITUFDLVNIQTI1NiIsIjAiOiJwYXlsb2FkIn0'
        assert_equal MiniFB.signed_request_params(secret, req), {"0" => "payload"}
    end

end
