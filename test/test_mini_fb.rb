require 'test/unit'
require 'rspec'
require 'uri'
require 'yaml'
require 'active_support/core_ext'
require '../lib/mini_fb'

describe "Some Feature" do

    before :all do
        @is_setup = true
        @config   = File.open(File.expand_path("~/.test_configs/mini_fb_tests.yml")) { |yf| YAML::load(yf) }
        puts "@config=" + @config.inspect
        MiniFB.log_level = :debug

        @oauth_url       = MiniFB.oauth_url(@config['fb_app_id'], # your Facebook App ID (NOT API_KEY)
                                            "http://localhost:3000", # redirect url
                                            :scope=>MiniFB.scopes.join(","))
        puts "If you need an access token, go here in your browser:"
        puts "#{@oauth_url}"
        puts "Then grab the 'code' parameter in the redirect url and add it to mini_fb_tests.yml."
    end



    before :each do
        # this code runs once per-test
    end

    it "should do something useful, rather than just being called test1" do
        # el code here
        puts 'whatup'
        true.should be_true
    end

    it 'test_uri_escape' do
        URI.escape("x=y").should eq("x=y")
    end

    it 'test_authenticate_as_app' do
        res = MiniFB.authenticate_as_app(@config["fb_api_key"], @config["fb_secret"])
        puts 'res=' + res.inspect
        res.should include("access_token")
        res["access_token"].should match(/^#{@config['fb_app_id']}/)#starts_with?(@config["fb_app_id"].to_s)
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
