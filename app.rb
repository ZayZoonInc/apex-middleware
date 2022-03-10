require 'rubygems'
require 'sinatra'
require 'sinatra/namespace'
require 'sinatra/reloader' if development?
require 'json'
require 'logger'
require 'httparty'
require 'zache'

AUTHORIZED_IPS = ENV.fetch('AUTHORIZED_IPS', "").split(',').map(&:strip).freeze
API_KEY = ENV.fetch('ZAYZOON_API_KEY', "").freeze
AUTHORIZED_CLIENT_IDS = ENV.fetch('AUTHORIZED_CLIENT_IDS', "").split(',').map(&:strip).freeze

def authorized_ip?
  unless AUTHORIZED_IPS.include?(request.ip)
    halt 401, 'Unauthorized Connection Attempt'
  end
end

def authorized_api_key?
  unless env["HTTP_AUTHORIZATION"] == "Bearer #{API_KEY}"
    halt 401, 'Unauthorized API Key'
  end
end

def authorized_client?
  client_id = params[:client_id]

  unless  client_id
    halt 404, 'No Client ID'
  end

  unless AUTHORIZED_CLIENT_IDS.include?(client_id)
    halt 401, 'Unauthorized Client ID'
  end
end

before do
  content_type 'application/json'
  authorized_ip?
  authorized_api_key?
end

namespace '/v1/companies/:client_id' do
  before do
    authorized_client?
  end

  get '' do
    r_status, r_body = ApexApi.new.get_data(request.path_info)
    status r_status
    body r_body
  end

  get '/short' do
    r_status, r_body = ApexApi.new.get_data(request.path_info)
    status r_status
    body r_body
  end

  get '/employees' do
    r_status, r_body = ApexApi.new.get_data(request.path_info)
    status r_status
    body r_body
  end

  get '/employees/:employee_id' do
    r_status, r_body = ApexApi.new.get_data(request.path_info)
    status r_status
    body r_body
  end

  get '/employees/:employee_id/paystubs' do
    r_status, r_body = ApexApi.new.get_data(request.path_info)
    status r_status
    body r_body
  end

  get '/employees/:employee_id/paystubs/:payroll_record_id/totals' do
    r_status, r_body = ApexApi.new.get_data(request.path_info)
    status r_status
    body r_body
  end

  get '/employees/:employee_id/paystubs/:payroll_record_id/deductions/:pay_date' do
    r_status, r_body = ApexApi.new.get_data(request.path_info)
    status r_status
    body r_body
  end
end

namespace '/v2/companies/:client_id/employees/:employee_id/deductions' do
  before do
    authorized_client?
  end

  get '' do
    r_status, r_body = ApexApi.new.get_data(request.path_info)
    status r_status
    body r_body
  end

  post '' do
    request.body.rewind  # in case someone already read it
    data = request.body.read
    r_status, r_body = ApexApi.new.post_data(request.path_info, data)
    status r_status
    body r_body
  end

  put '/:deduction_id' do
    request.body.rewind  # in case someone already read it
    data = request.body.read
    r_status, r_body = ApexApi.new.put_data(request.path_info, data)
    status r_status
    body r_body
  end
end

get '/' do
  'ok'
end


class ApexApi
  include HTTParty
  logger ::Logger.new(STDOUT), :debug, :curl
  base_uri 'https://api.employeronthego.com/api'
  AUTH_URL = "https://oauth.employeronthego.com/token".freeze
  CLIENT_ID = ENV.fetch('APEX_CLIENT_ID').freeze
  CLIENT_SECRET = ENV.fetch('APEX_CLIENT_SECRET').freeze
  TOKEN_EXPIRY = 1740.freeze
  CACHE = Zache.new

  def get_data(endpoint)
    response = self.class.get(
      endpoint,
      headers:
      {
        "Content-Type": "application/json",
        Authorization: "Bearer #{token}"
      }
    )
    [response.code, response.body]
  end

  def post_data(endpoint, data)
    response = self.class.post(
      endpoint,
      headers:
      {
        "Content-Type": "application/json",
        Authorization: "Bearer #{token}"
      },
      body: data
    )
    [response.code, response.body]
  end

  def put_data(endpoint, data)
    response = self.class.put(
      endpoint,
      headers:
      {
        "Content-Type": "application/json",
        Authorization: "Bearer #{token}"
      },
      body: data
    )
    [response.code, response.body]
  end

  def token
    CACHE.get(:bearer_token, lifetime: TOKEN_EXPIRY) { get_token() }
  end

  def get_token
    response = HTTParty.post(
      AUTH_URL,
      headers:
      {
        "Content-Type": "application/x-www-form-urlencoded",
        Authorization: "Basic #{Base64.strict_encode64("#{CLIENT_ID}:#{CLIENT_SECRET}")}"
      },
      body: {
        grant_type: 'client_credentials'
      }
    )

    return false unless response.code == 200

    JSON.parse(response.body)['access_token']
  end
end
