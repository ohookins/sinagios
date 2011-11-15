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

desc 'Package Sinagios using fpm'
task :package do
  require 'fileutils'
  require 'tempfile'
  require 'fpm' # just to make sure we have it before proceeding

  # Create a tempdir and copy things into place for fpm
  Dir.mktmpdir do |dir|
    FileUtils.mkdir_p("#{dir}/usr/lib/sinagios/")
    FileUtils.cp_r(['sinagios.rb', 'lib'], "#{dir}/usr/lib/sinagios/")

    # Create the RPM with fpm
    # TODO: Use fpm as a library
    PKGNAME = 'sinagios'
    PKGVERSION = '1.0.0'
    PKGDEPENDS = 'ruby'
    PKGARCH = 'noarch'
    PKGMAINT = 'ohookins@gmail.com'
    PKGTYPE = 'rpm'
    PKGSOURCE = 'dir'
    sh "fpm -n #{PKGNAME} -v #{PKGVERSION} -d #{PKGDEPENDS} -a #{PKGARCH} -m #{PKGMAINT} -C #{dir} -t #{PKGTYPE} -s #{PKGSOURCE}"
  end
end

desc "Package required Gems as RPM using fpm"
task :package_gems do
  require 'fpm' # just to make sure we have it before proceeding

  # list our required gems and versions
  gemlist = { 'rake'      => '0.8.7',
              'sinatra'   => '1.3.1',
              'rspec'     => '2.5.0',
              'rack-test' => '0.6.1',
              'mocha'     => '0.9.8',
              'json'      => '1.5.3'
            }

  gemlist.each_pair do |gemname, gemversion|
    sh "fpm -s gem -t rpm #{gemname} -v #{gemversion}"
  end
end
