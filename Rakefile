# Dummy default task
task :default do
  puts 'Run rake -T to get a list of available tasks.'
end

# Allow the rakefile targets to be used without rspec/rcov being present
def safe_require(file, &block)
  begin
    require file
    yield block
  rescue LoadError
    # do nothing
  end
end

safe_require 'rspec/core/rake_task' do
  desc 'Run tests'
  RSpec::Core::RakeTask.new('test') do |t|
    t.pattern = 'spec/*_spec.rb'
  end
end

safe_require 'rcov/rcovtask' do
  Rcov::RcovTask.new do |t|
    t.test_files = FileList['spec/*_spec.rb']
    t.rcov_opts << '--exclude /gems/,/var\/lib/,/usr/'
  end
end

desc 'Run the application from the console.'
task :run do
  sh "ruby #{File.join(File.dirname(__FILE__), 'sinagios.rb')}"
end
