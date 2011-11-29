#!/usr/bin/env ruby
#
# Reference client for Sinagios RESTful Nagios API.
# Copyright 2011 Oliver Hookins
# Licenced under the GPLv2 or later.

require 'net/http'
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
      opts.on('-d <duration>', '--duration', 'Duration of scheduled downtime to be set, in seconds') do |d|
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
      self.send(@operation)
    else
      $stderr.puts "Operation '#{@operation}' is not supported."
      $stderr.puts "Valid operations are: #{valid_operations().join(', ')}\n\n"
      usage()
    end
  end

  def schedule()
    #
  end

  def delete()
    #
  end

  private
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
end

# Don't invoke client class unless we're actually running the client.
if __FILE__ == $PROGRAM_NAME
  sc = SinagiosClient.new(ARGV)
  sc.run()
end
