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

desc 'Run the application from the console directly (for development)'
task :run do
  sh "ruby #{File.join(File.dirname(__FILE__), 'sinagios.rb')}"
end

desc 'Run the application daemonised through rackup (simulates production)'
task :rackup do
  sh "rackup -I #{File.dirname(__FILE__)} -r sinagios -p 4567 -E production -D -s thin rpmfiles/config.ru"
end

desc 'Package Sinagios using fpm'
task :package do
  require 'fileutils'
  require 'tempfile'
  require 'fpm' # just to make sure we have it before proceeding

  # Create a tempdir and copy things into place for fpm
  Dir.mktmpdir do |dir|
    FileUtils.chmod(0755, dir) # due to https://github.com/jordansissel/fpm/issues/121
    FileUtils.mkdir_p("#{dir}/usr/lib/sinagios/")
    FileUtils.mkdir_p("#{dir}/etc/sinagios/")
    FileUtils.mkdir_p("#{dir}/etc/logrotate.d/")
    FileUtils.mkdir_p("#{dir}/etc/rc.d/init.d/")
    FileUtils.mkdir_p("#{dir}/var/log/sinagios/")
    FileUtils.cp_r(['sinagios.rb', 'lib'], "#{dir}/usr/lib/sinagios/")
    FileUtils.cp_r(['rpmfiles/config.ru', 'rpmfiles/sinagios.conf'], "#{dir}/etc/sinagios/")
    FileUtils.cp_r('rpmfiles/sinagios.logrotate', "#{dir}/etc/logrotate.d/")
    FileUtils.cp_r('rpmfiles/sinagios.init', "#{dir}/etc/rc.d/init.d/")

    # Create the RPM with fpm
    # TODO: Use fpm as a library
    PKGNAME = 'sinagios'
    PKGVERSION = '1.0.0'
    PKGDEPENDS = 'ruby'
    PKGARCH = 'noarch'
    PKGMAINT = 'ohookins@gmail.com'
    PKGTYPE = 'rpm'
    PKGSOURCE = 'dir'
    PKGPRESCRIPT = 'rpmfiles/sinagios.preinstall'
    PKGPOSTSCRIPT = 'rpmfiles/sinagios.postinstall'
    PKGFILELIST = 'rpmfiles/sinagios.filelist'
    sh "fpm -n #{PKGNAME} -v #{PKGVERSION} -d #{PKGDEPENDS} -a #{PKGARCH} -m #{PKGMAINT} -C #{dir} -t #{PKGTYPE} -s #{PKGSOURCE} --pre-install #{PKGPRESCRIPT} --post-install #{PKGPOSTSCRIPT} --inputs #{PKGFILELIST}"
  end
end

desc "Package required Gems as RPM using fpm"
task :package_gems do
  require 'fpm' # just to make sure we have it before proceeding

  # list our required gems and versions
  gemlist = { 'rake'      => '0.8.7',
              'rack'      => '1.3.5',
              'thin'      => '1.2.11',
              'sinatra'   => '1.3.1',
              'rack-test' => '0.6.1',
              'mocha'     => '0.9.8',
              'json'      => '1.5.3',
              'rspec'     => '2.5.0',
              # subcomponents/dependencies:
              'rspec-core'         => '2.5.0',
              'rspec-expectations' => '2.5.0',
              'rspec-mocks'        => '2.5.0',
              'rack-protection'    => '1.1.4',
              'tilt'               => '1.3.3',
              'eventmachine'       => '0.12.10',
              'daemons'            => '1.1.4'
            }

  gemlist.each_pair do |gemname, gemversion|
    sh "fpm -s gem -t rpm #{gemname} -v #{gemversion}"
  end
end
