# Configure Rails Envinronment
ENV["RAILS_ENV"] ||= "test"
require 'simplecov'
SimpleCov.start

require File.expand_path("../dummy/config/environment.rb",  __FILE__)
require "rspec/rails"
require 'rspec/expectations'
require 'equivalent-xml'

require "factory_girl"

ActionMailer::Base.delivery_method = :test
ActionMailer::Base.perform_deliveries = true
ActionMailer::Base.default_url_options[:host] = "test.com"

Rails.backtrace_cleaner.remove_silencers!

# generate migration files
require "#{File.dirname(__FILE__)}/../lib/rails/generators/mogile_image_store/mogile_image_store_generator"
Dir["#{File.dirname(__FILE__)}/dummy/db/migrate/*_create_mogile_image_tables.rb"].each { |f| File.unlink f }
#save current directory
cwd = Dir.pwd
Dir.chdir File.expand_path("../dummy/", __FILE__)
generator = MogileImageStoreGenerator.new
generator.create_migration_file
Dir.chdir cwd
# Run any available migration
ActiveRecord::Migration.suppress_messages do
  ActiveRecord::Migrator.migrate File.expand_path("../dummy/db/migrate/", __FILE__)
end
# Load initializer
require "#{File.dirname(__FILE__)}/dummy/config/initializers/mogile_image_store.rb"

# Load support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  # Remove this line if you don't want RSpec's should and should_not
  # methods or matchers
  config.include RSpec::Matchers

  # == Mock Framework
  config.mock_with :rspec

  require "database_cleaner"
  include MogilefsHelperMethods
  config.before(:each) do |example|
    if example.metadata[:mogilefs]
      mogilefs_prepare
      @mg = MogileFS::MogileFS.new({
        :domain => MogileImageStore.backend['domain'],
        :hosts  => MogileImageStore.backend['hosts']
      })
    end
    if example.metadata[:truncation]
      DatabaseCleaner.strategy = :truncation
    else
      DatabaseCleaner.strategy = :transaction
    end
    DatabaseCleaner.start
  end
  config.after(:each) do |example|
    mogilefs_cleanup if example.metadata[:mogilefs]
    DatabaseCleaner.clean
  end

  # filtering
  config.filter_run :focus => true
  config.run_all_when_everything_filtered = true
end
