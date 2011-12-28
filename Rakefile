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

  begin
    # Create a tempdir and copy things into place for fpm.
    # The tempdir manipulation is a bit ugly, but done for compatibility reasons
    t = Tempfile.new('w')
    dir = t.path
    t.close
    File.unlink(t.path)
    FileUtils.mkdir(dir)
    FileUtils.chmod(0755, dir) # due to https://github.com/jordansissel/fpm/issues/121
    FileUtils.mkdir_p("#{dir}/usr/lib/sinagios/")
    FileUtils.mkdir_p("#{dir}/etc/sinagios/")
    FileUtils.mkdir_p("#{dir}/etc/logrotate.d/")
    FileUtils.mkdir_p("#{dir}/etc/rc.d/init.d/")
    FileUtils.mkdir_p("#{dir}/var/log/sinagios/")
    FileUtils.cp_r(['sinagios.rb', 'lib'], "#{dir}/usr/lib/sinagios/")
    FileUtils.cp_r(['rpmfiles/config.ru', 'rpmfiles/sinagios.conf'], "#{dir}/etc/sinagios/")
    FileUtils.cp_r('rpmfiles/sinagios.logrotate', "#{dir}/etc/logrotate.d/sinagios")
    FileUtils.cp_r('rpmfiles/sinagios.init', "#{dir}/etc/rc.d/init.d/sinagios")
    FileUtils.chmod(0555, "#{dir}/etc/rc.d/init.d/sinagios")

    # Create the RPM with fpm
    # TODO: Use fpm as a library
    PKGNAME = 'sinagios'
    PKGVERSION = '1.0.0'
    PKGDEPENDS = ['ruby', 'nagios', 'rubygem-rack', 'rubygem-json', 'rubygem-thin', 'rubygem-sinatra']
    PKGARCH = 'noarch'
    PKGMAINT = 'ohookins@gmail.com'
    PKGTYPE = 'rpm'
    PKGSOURCE = 'dir'
    PKGPRESCRIPT = 'rpmfiles/sinagios.preinstall'
    PKGPOSTSCRIPT = 'rpmfiles/sinagios.postinstall'
    PKGFILELIST = 'rpmfiles/sinagios.filelist'
    PKGCONFIGS = ['/etc/sinagios/config.ru', '/etc/sinagios/sinagios.conf']

    # Actually create the package now
    sh "fpm -n #{PKGNAME} -v #{PKGVERSION} #{PKGDEPENDS.map { |p| '-d '+p }.join(' ')} -a #{PKGARCH} -m #{PKGMAINT} -C #{dir} -t #{PKGTYPE} -s #{PKGSOURCE} --pre-install #{PKGPRESCRIPT} --post-install #{PKGPOSTSCRIPT} --inputs #{PKGFILELIST} #{PKGCONFIGS.map { |c| '--config-files '+c }.join(' ')}"

  # ensure the tmpdir is cleaned up regardless
  ensure
    FileUtils.rm_rf(dir)
  end
end

desc "Package required Gems as RPM using fpm"
task :package_gems do
  require 'fpm' # just to make sure we have it before proceeding

  # Couple of convenience functions to reuse Gemfile information
  def source(name); end

  @gemlist = {}
  def gem(name, version)
    @gemlist[name] = version
  end

  # load list of gems from the Bundler Gemfile
  Kernel.load(File.join(File.dirname(__FILE__), 'Gemfile'))

  @gemlist.each_pair do |name, version|
    sh "fpm -s gem -t rpm #{name} -v #{version}"
  end
end
