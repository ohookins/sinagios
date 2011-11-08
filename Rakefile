require 'rspec/core/rake_task'

# Dummy default task
task :default do
  puts 'Run rake -T to get a list of available tasks.'
end

desc 'Run tests'
RSpec::Core::RakeTask.new('test') do |t|
  t.pattern = 'spec/*_spec.rb'
end

desc 'Run the application from the console.'
task :run do
  sh "ruby #{File.join(File.dirname(__FILE__), 'sinagios.rb')}"
end
