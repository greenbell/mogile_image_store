require "bundler/gem_tasks"

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

task :default => :spec

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "mogile_image_store #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include(%w[app/**/*.rb lib/**/*.rb])
end

require 'cover_me'
CoverMe.config do |c|
  c.at_exit = Proc.new {}
  c.file_pattern = /(#{c.project.root}\/app\/.+\.rb|#{c.project.root}\/lib\/.+\.rb)/ix
end

namespace :cover_me do
  task :report do
    CoverMe.complete!
  end

end

task :test do
  Rake::Task['cover_me:report'].invoke
end

task :spec do
  Rake::Task['cover_me:report'].invoke
end
