require 'rspec'
require 'uri'
require 'yaml'
require 'active_support/core_ext'
require_relative '../lib/mini_fb'

describe MiniFB do

    before :all do
        @is_setup = true
        file_path = File.expand_path("../mini_fb_tests.yml", File.dirname(__FILE__))
        @config   = File.open(file_path) { |yf| YAML::load(yf) }
        MiniFB.log_level = :warn

        @oauth_url       = MiniFB.oauth_url(@config['fb_app_id'],
                                            "http://localhost:3000", # redirect url
                                            :scope=>MiniFB.scopes.join(","))
    end



    before :each do
        # this code runs once per-test
    end

    it 'test_uri_escape' do
        URI.escape("x=y").should eq("x=y")
    end

    it 'test_authenticate_as_app' do
        res = MiniFB.authenticate_as_app(@config["fb_api_key"], @config["fb_secret"])
        res.should include("access_token")
        res["access_token"].should match(/^#{@config['fb_app_id']}/)#starts_with?(@config["fb_app_id"].to_s)
    end


    it 'test_signed_request_params' do
        # Example request and secret taken from http://developers.facebook.com/docs/authentication/canvas
        secret = 'secret'
        req = 'vlXgu64BQGFSQrY0ZcJBZASMvYvTHu9GQ0YM9rjPSso.eyJhbGdvcml0aG0iOiJITUFDLVNIQTI1NiIsIjAiOiJwYXlsb2FkIn0'
        expect(MiniFB.signed_request_params(secret, req)).to eq({"0" => "payload"})
    end

end


def access_token
    @config['access_token']
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
