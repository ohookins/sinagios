# Add local lib directory to the search path for libraries
$: << File.join(File.dirname(__FILE__), 'lib')

require 'rubygems'
require 'sinatra'
require 'json'
require 'nagios'

# List all the downtime scheduled for all hosts and services
get '/v1/downtime' do
  nagios = Nagios.new
  content_type 'application/json', :charset => 'utf-8'
  nagios.get_all_downtime.to_json
end

# List all the downtime scheduled for one host and its services
get '/v1/downtime/:name' do
  nagios = Nagios.new
  content_type 'application/json', :charset => 'utf-8'
  nagios.get_all_downtime[params[:name]].to_json
end

# Delete all downtime scheduled for one host and its services
delete '/v1/downtime/:name' do
  nagios = Nagios.new

  if nagios.get_all_downtime.has_key?(params[:name])
    nagios.delete_all_downtime_for_host(params[:name])
  else
    return "No downtime detected for #{params[:name]}"
  end
end

# Create downtime for the named machine. It's not really practical to make this
# an idempotent action so this will always create new downtime. Hey, you can
# always just delete all downtime for the host before making this call!
post '/v1/downtime/:name' do
  "Not yet implemented!"
end
