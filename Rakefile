require 'spec/rake/spectask'

desc 'Run tests'
Spec::Rake::SpecTask.new('test') do |t|
  t.spec_files = FileList['tests/*_spec.rb']
end

task :default do
  puts 'Run rake -T to get a list of available tasks.'
end
