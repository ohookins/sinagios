require 'sinagios'
require 'logger'

# Set up logging
STDERR.reopen(File.new('/var/log/sinagios/error.log','a'))

# Rack::CommonLogger will call @logger.write :(
Logger.class_eval { alias :write :'<<' }
logger = Logger.new('/var/log/sinagios/access.log')
use Rack::CommonLogger, logger

# Run the app
run Sinatra::Application
