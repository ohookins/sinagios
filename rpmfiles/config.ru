require 'sinagios'
STDERR.reopen(File.new('/var/log/sinagios/error.log','a'))
run Sinatra::Application
