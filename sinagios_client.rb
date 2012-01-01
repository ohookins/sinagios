#!/usr/bin/env ruby
#
# Reference client for Sinagios RESTful Nagios API.
# Copyright 2011 Oliver Hookins
# Licenced under the GPLv2 or later.

require 'net/https' # also pulls in net/http and uri
require 'yaml'
require 'optparse'

class SinagiosClient
  def initialize(argv)
    @operation = nil
    @options = {:warnings => true, :use_auth => false}
    @option_parser = OptionParser.new do |opts|
      # Pull in config values from a config file
      parse_config_file()

      # Parse options from command line, which can override options from file
      opts.banner = "Usage: #{$0} -u <URI> -a <author> [-p <password>] -o <operation> -h <hosts> [-d <duration> -c <comment>]"
      opts.on('-u <uri>', '--uri', 'The URI of the Sinagios API') do |u|
	@uri = parse_uri(u)
      end
      opts.on('-a <author>', '--author', 'Author field when scheduling downtime. Also used for HTTP Basic Authentication if applicable') do |a|
        @options[:author] = a
      end
      opts.on('-h <hosts>', '--hosts', 'Host to schedule/destroy downtime for. Multiple hosts can be separated by commas e.g. host1,host2') do |h|
        @options[:hosts] = h.split(',')
      end
      opts.on('-p <password>', '--password', 'Password used with HTTP Basic Authentication (if applicable)') do |p|
        @options[:password] = p
      end
      opts.on('-o <operation>', '--operation', "One of: #{valid_operations().join('/')}") do |o|
        @operation = o
      end
      opts.on('-d <duration>', '--duration', Integer, 'Duration of scheduled downtime to be set, in seconds') do |d|
        @options[:duration] = d
      end
      opts.on('-c <comment>', '--comment', 'Comment to add to the scheduled downtime') do |c|
        @options[:comment] = c
      end
      opts.on('-w', '--no-warnings', 'Disable SSL verification warnings') do
        @options[:warnings] = false
      end
    end

    # Nicely handle incorrect options rather than spewing forth the exception
    begin
      @option_parser.parse!(argv)
    rescue OptionParser::InvalidOption => detail
      $stderr.puts detail.message
      usage()
    end

    # At a minimum we need an operation to progress. Each operation can handle
    # checking for its required options by itself.
    if ! @operation
      $stderr.puts "Minimum required arguments: --operation, --uri, --hosts\n\n"
      usage()
    end
  end

  # Just a simple wrapper around the URI parsing
  def parse_uri(uri)
    # Parse the URI immediately.
    begin
      return URI.parse(uri)
    rescue URI::InvalidURIError => detail
      $stderr.puts detail.message
      exit(1)
    end
  end

  # Just run which ever operation has been set, but give an informative message
  # if the operation doesn't exist yet.
  def run()
    if self.respond_to?(@operation)
      # Set return code based on success of operation
      rc = self.send(@operation) ? 0 : 1
    else
      $stderr.puts "Operation '#{@operation}' is not supported."
      $stderr.puts "Valid operations are: #{valid_operations().join(', ')}\n\n"
      usage()
    end

    return rc
  end

  # schedule downtime for a host and all its services
  def schedule()
    # Check options and set up the form data used for the downtime
    check_valid_options([:hosts, :uri, :author, :comment, :duration])
    formdata = {'author' => @options[:author], 'comment' => @options[:comment], 'duration' => @options[:duration].to_s}

    # Make a single connection to avoid multiple handshakes
    set_up_connection()

    # Iterate over each host entering maintenance
    success = true
    @options[:hosts].each do |host|
      res = post_request(host, formdata)

      if res.code == '401'
        if @options[:use_auth] == false
          # Enable authentication and restart the block after checking we have credentials.
          check_auth_creds()
          @options[:use_auth] = true
          redo
        else
          # authentication was used but the request failed anyway
          $stderr.puts "#{res.code} - authentication failed with supplied credentials."
          success = false
        end
      elsif res.code != '201'
        $stderr.puts "#{res.code} #{res.body} - downtime for #{host} may not have been scheduled."
        success = false
      else
        puts "Downtime scheduled for #{host}"
      end
    end

    # Tear down HTTP connection
    finish_connection()
    return success
  end

  # delete all downtime for one or more hosts
  def delete()
    check_valid_options([:hosts, :uri])

    # Make a single connection to avoid multiple handshakes
    set_up_connection()

    # Iterate over each host leaving maintenance
    success = true
    @options[:hosts].each do |host|
      res = delete_request(host)

      if res.code == '404'
        $stderr.puts "#{res.code} - downtime for #{host} was not found."
        success = false
      elsif res.code == '401'
        if @options[:use_auth] == false
          # Enable authentication and restart the block after checking we have credentials.
          check_auth_creds()
          @options[:use_auth] = true
          redo
        else
          # authentication was used but the request failed anyway
          $stderr.puts "#{res.code} - authentication failed with supplied credentials."
          success = false
        end
      elsif res.code != '200'
        $stderr.puts "#{res.code} #{res.body} - downtime for #{host} may not have been deleted."
        success = false
      else
        puts "Downtime deleted for #{host}"
      end
    end

    # Tear down HTTP connection
    finish_connection()
    return success
  end

  private
  # Check that we have a username and password for Basic Auth
  def check_auth_creds()
    if ! (@options.has_key?(:author) and @options.has_key?(:password))
      $stderr.puts "Both author (username) and password are required, since authentication was requested."
      finish_connection()
      exit(1)
    end
  end

  # Set authentication on a request
  def set_request_auth(request)
    if @options[:use_auth]
      request.basic_auth(@options[:author], @options[:password])
    end
  end

  # Do an HTTP POST
  def post_request(host, formdata)
    req = Net::HTTP::Post.new(request_path(host))
    set_request_auth(req)
    req.set_form_data(formdata)
    return @http.request(req)
  end

  # Do an HTTP DELETE
  def delete_request(host)
    req = Net::HTTP::Delete.new(request_path(host))
    set_request_auth(req)
    return @http.request(req)
  end

  # Assemble the path for the request based on the host
  def request_path(host)
    return (@uri.path + "/downtime/#{host}").squeeze('/') # remove duplicate slashes
  end

  # Check the options hash for all required options and do some validation
  def check_valid_options(options)
    sufficient = options.all? { |o| @options.has_key?(o) }

    if ! sufficient
      $stderr.puts "Minimum required arguments: #{options.collect { |o| '--' + o.to_s }.join(', ')}\n\n"
      usage()
    end
  end

  # just return our default config location
  def config_file_path()
    File.join(ENV['HOME'], '.sinagios.conf')
  end

  # Load a config file
  def parse_config_file()
    # Use a config file if present
    if File.readable?(config_file_path())
      config = YAML::load_file(config_file_path())
    end

    # Load defaults from config file
    if config
      # Parse the URI into a usable object immediately.
      if config.has_key?('uri')
	@uri = parse_uri(config['uri'])
      else
	@uri = nil
      end

      # Other settings are just strings
      @options[:author] = config['author'] || nil
      @options[:password] = config['password'] || nil

      # Need to handle the warnings option specially as it is a boolean
      @options[:warnings] = (config.has_key?('warnings') ? config['warnings'] : true)
    end
  end

  # print usage and exit non-zero
  def usage()
    $stderr.puts @option_parser.help()
    exit(1)
  end

  # Helper for generating a list of valid operations we can run against the API
  def valid_operations()
    self.methods - Object.methods - ['run']
  end

  # Set up the HTTP(S) connection
  def set_up_connection()
    @http = Net::HTTP.new(@uri.host, @uri.port)
    if @uri.scheme == 'https'
      @http.use_ssl = true

      # Enable SSL verification warnings by default, but allow them to be
      # disabled.
      if ! @options[:warnings]
        @http.instance_eval do
          @ssl_context = OpenSSL::SSL::SSLContext.new
          @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
      end
    end
  end

  # Tear down the HTTP(S) connection
  def finish_connection()
    if @http.started?
      @http.finish()
    end
  end
end

# Don't invoke client class unless we're actually running the client.
if __FILE__ == $PROGRAM_NAME
  sc = SinagiosClient.new(ARGV)
  exit(sc.run())
end
