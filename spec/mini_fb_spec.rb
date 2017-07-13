require 'rspec'
require 'uri'
require 'yaml'
require 'active_support/core_ext'
require_relative '../lib/mini_fb'
require_relative 'test_helper'

describe MiniFB do
  before do
    MiniFB.log_level = :warn
  end

  let(:app_id){TestHelper.config['app_id']}
  let(:app_secret){TestHelper.config['app_secret']}
  let(:access_token){TestHelper.config['access_token']}

  describe '#authenticate_as_app' do

    it 'authenticates with valid params' do
      res = MiniFB.authenticate_as_app(app_id, app_secret)
      expect(res).to include('access_token')
      expect(res['access_token']).to match(/^#{app_id}/)
    end
  end

  describe '#signed_request_params' do
    let (:req) { 'vlXgu64BQGFSQrY0ZcJBZASMvYvTHu9GQ0YM9rjPSso.eyJhbGdvcml0aG0iOiJITUFDLVNIQTI1NiIsIjAiOiJwYXlsb2FkIn0' }
    let (:secret) { 'secret' }

    it 'decodes params' do
      expect(MiniFB.signed_request_params(secret, req)).to eq({"0" => "payload"})
    end
  end

  describe '#exchange_token' do
    let(:invalid_app_id) { '12345' }
    let(:invalid_secret) { 'secret' }
    let(:invalid_access_token) { 'token' }

    it 'returns valid long-lived token' do
      res = MiniFB.fb_exchange_token(app_id, app_secret, access_token)

      expect(res).to include('access_token')
      expect(res).to include('expires_in')
    end

    it 'raises error on request with invalid params' do
      error_message = 'Facebook error 400: OAuthException: '\
        'Error validating application. '\
        'Cannot get application info due to a system error.'

      expect do
        MiniFB.fb_exchange_token(invalid_app_id, invalid_secret, invalid_access_token)
      end.to raise_error(MiniFB::FaceBookError, error_message)
    end

    it 'raise error on request with invalid token' do
      error_message = 'Facebook error 400: OAuthException: '\
        'Invalid OAuth access token.'

      expect do
        MiniFB.fb_exchange_token(app_id, app_secret, invalid_access_token)
      end.to raise_error(MiniFB::FaceBookError, error_message)
    end
  end
end
