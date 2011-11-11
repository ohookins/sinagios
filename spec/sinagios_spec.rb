require 'sinagios'
require 'rspec'
require 'rack/test'
require 'mocha'

describe 'the Sinagios app' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  # Mock the Nagios class so we don't have to deal with real data here
  before(:each) do
    @fakenagios = mocha()
    Nagios.stubs(:new).returns(@fakenagios)
  end

  it 'returns all downtime correctly when downtime exists' do
    # generate some fake downtime data
    downtime = {'localhost' => {:host => [1], :service => [2]}}
    @fakenagios.expects(:get_all_downtime).returns(downtime)

    get '/v1/downtime'
    last_response.body.should == downtime.to_json
    last_response.status.should == 200
  end

  it 'returns an empty hash when there is no downtime' do
    @fakenagios.expects(:get_all_downtime).returns({})

    get '/v1/downtime'
    last_response.body.should == {}.to_json
    last_response.status.should == 200
  end

  it 'returns just the downtime for a particular host' do
    # generate some fake downtime data
    downtime = {'localhost' => {:host => [1], :service => [2]}}
    @fakenagios.expects(:get_all_downtime).returns(downtime)

    get '/v1/downtime/localhost'
    last_response.body.should == downtime['localhost'].to_json
    last_response.status.should == 200
  end

  it 'returns an error when a specific host has no downtime' do
    @fakenagios.expects(:get_all_downtime).returns({})

    get '/v1/downtime/localhost'
    last_response.body.should == ''
    last_response.status.should == 404
  end

  it 'successfully deletes all host downtime if present' do
    # generate some fake downtime data
    downtime = {'localhost' => {:host => [1], :service => [2]}}
    @fakenagios.expects(:get_all_downtime).returns(downtime)

    # mock the deletion
    @fakenagios.expects(:delete_all_downtime_for_host).with('localhost').returns('All downtime for localhost deleted!')

    delete '/v1/downtime/localhost'
    last_response.body.should == 'All downtime for localhost deleted!'
    last_response.status.should == 200
  end

  it 'returns an error when trying to delete non-existent downtime' do
    @fakenagios.expects(:get_all_downtime).returns({})

    delete '/v1/downtime/localhost'
    last_response.body.should == ''
    last_response.status.should == 404
  end

  it 'does not yet support creation of new downtime' do
    post '/v1/downtime/localhost'
    last_response.body.should == "Not yet implemented!"
    last_response.status.should == 404
  end
end
