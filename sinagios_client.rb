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
    @options = {}
    @option_parser = OptionParser.new do |opts|
      # Use a config file if present
      if File.readable?(config_file_path())
        config = YAML::load_file(config_file_path())
      end

      # Load defaults from config file
      if config
        @options[:uri] = config[:uri] || nil
        @options[:author] = config[:author] || nil
        @options[:password] = config[:password] || nil
      end

      # Parse options from command line, which can override options from file
      opts.banner = "Usage: #{$0} -u <URI> -a <author> [-p <password>] -o <operation> -h <hosts> [-d <duration> -c <comment>]"
      opts.on('-u <uri>', '--uri', 'The URI of the Sinagios API') do |u|
        @options[:uri] = u
      end
      opts.on('-a <author>', '--author', 'Author field when scheduling downtime. Also used for HTTP Basic Authentication if applicable') do |a|
        @options[:author] = a
      end
      opts.on('-h <hosts>', '--hosts', 'Host to schedule/destroy downtime for. Multiple hosts can be separated by colons e.g. host1:host2') do |h|
        @options[:hosts] = h.split(':')
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

      if res.code != '201'
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
  # Do an HTTP POST
  def post_request(host, formdata)
    req = Net::HTTP::Post.new(request_path(host))
    req.set_form_data(formdata)
    return @http.request(req)
  end

  # Do an HTTP DELETE
  def delete_request(host)
    @http.delete(request_path(host))
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

    begin
      @uri = URI.parse(@options[:uri])
    rescue URI::InvalidURIError => detail
      $stderr.puts detail.message
      exit(1)
    end
  end

  # just return our default config location
  def config_file_path()
    File.join(ENV['HOME'], '.sinagios.conf')
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
    @uri = URI.parse(@options[:uri])
    @http = Net::HTTP.new(@uri.host, @uri.port)
    if @uri.scheme == 'https'
      @http.use_ssl = true
      @http.instance_eval do
        @ssl_context = OpenSSL::SSL::SSLContext.new
        @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
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
