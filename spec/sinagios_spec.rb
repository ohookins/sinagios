require 'sinagios'
require 'rspec'
require 'rack/test'

describe 'the Sinagios app' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  it 'does not yet support creation of new downtime' do
    post '/v1/downtime/localhost'
    last_response.body.should == "Not yet implemented!"
    last_response.status.should == 404
  end
end
