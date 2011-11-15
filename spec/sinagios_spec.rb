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

  it 'creates new downtime successfully when provided valid input' do
    host = 'localhost'
    duration = '5'
    author = 'Test Dude'
    comment = 'Test downtime'

    # Mock calls to schedule the downtime
    @fakenagios.expects(:schedule_host_downtime).with(host, duration, author, comment)
    @fakenagios.expects(:schedule_services_downtime).with(host, duration, author, comment)

    post "/v1/downtime/#{host}", params = {:duration => duration, :author => author, :comment => comment}
    last_response.body.should == ''
    last_response.status.should == 200
  end

  it 'returns an error when no required fields for scheduling downtime are supplied' do
    post '/v1/downtime/localhost'
    last_response.body.should == "Require these fields: duration, author, comment\n"
    last_response.status.should == 400
  end

  it 'returns an error when no duration for scheduling downtime is supplied' do
    post '/v1/downtime/localhost', params = {:author => 'Test Guy', :comment => 'No duration'}
    last_response.body.should == "Require these fields: duration, author, comment\n"
    last_response.status.should == 400
  end

  it 'returns an error when invalid author information for scheduling downtime is supplied' do
    post '/v1/downtime/localhost', params = {:duration => '60', :author => '$@!@!', :comment => 'No duration'}
    last_response.body.should == "Require these fields: duration, author, comment\n"
    last_response.status.should == 400
  end

  it 'passes the health check when the nagios object is created successfully' do
    get '/v1/health'
    last_response.body.should == 'OK'
    last_response.status.should == 200
  end

  it 'fails the health check when the nagios object throws an exception during creation' do
    Nagios.stubs(:new).raises(Exception)
    get '/v1/health'
    last_response.body.should_not == 'OK'
    last_response.status.should == 500
  end
end
