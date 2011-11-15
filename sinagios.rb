# Add local lib directory to the search path for libraries
$: << File.join(File.dirname(__FILE__), 'lib')

require 'rubygems'
require 'sinatra'
require 'json'
require 'nagios'

# List all the downtime scheduled for all hosts and services
get '/v1/downtime/?' do
  nagios = Nagios.new
  content_type 'application/json', :charset => 'utf-8'
  nagios.get_all_downtime.to_json
end

# List all the downtime scheduled for one host and its services
get '/v1/downtime/:name/?' do
  nagios = Nagios.new
  content_type 'application/json', :charset => 'utf-8'
  downtime = nagios.get_all_downtime[params[:name]]

  # Make sure we have something to return, otherwise return 404
  if downtime
    downtime.to_json
  else
    status 404
  end
end

# Delete all downtime scheduled for one host and its services
delete '/v1/downtime/:name/?' do
  nagios = Nagios.new

  if nagios.get_all_downtime.has_key?(params[:name])
    nagios.delete_all_downtime_for_host(params[:name])
  else
    status 404
  end
end

# Create downtime for the named machine. It's not really practical to make this
# an idempotent action so this will always create new downtime. Hey, you can
# always just delete all downtime for the host before making this call!
post '/v1/downtime/:name/?' do
  # Do some basic validation
  # FIXME: Better feedback of problems.
  begin
    host = params[:name].gsub(/[^a-zA-Z0-9\-\.]/, '')
    duration = Integer(params[:duration])
    author = params[:author].gsub(/[^a-zA-Z0-9\-\.#\s]/, '')
    comment = params[:comment].gsub(/[^a-zA-Z0-9\-\.#\s]/, '')

    # Make sure we have input data from the POST operation
    if [params[:duration], params[:author], params[:comment]].include?(nil)
      raise Exception
    end

    # Also check that we have something useful after gsub
    if [host, author].include?('')
      raise Exception
    end

  rescue Exception
    # nil.gsub raises NoMethodError but we catch a generic exception to handle
    # nil values for duration as well
    status 400
    return "Require these fields: duration, author, comment\n"
  end

  # Schedule the downtime for the host and the services. They may not start at
  # exactly the same time by doing it this way, but it's not a big deal
  # usually.
  nagios = Nagios.new
  nagios.schedule_host_downtime(params[:name], params[:duration], params[:author], params[:comment])
  nagios.schedule_services_downtime(params[:name], params[:duration], params[:author], params[:comment])
  status 200
end

# Health check for monitoring systems
get '/v1/health/?' do
  # Just try to verify the command and status files look ok, rescue the
  # exception and allow the message to propagate to the output with a
  # reasonable error code.
  begin
    nagios = Nagios.new
  rescue Exception => detail
    body detail.message
    status 500
  else
    body 'OK'
    status 200
  end
end
