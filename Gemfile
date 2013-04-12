source 'https://rubygems.org'

gem "rails", "~> 3.0"
gem "rmagick", :require => false
gem "mogilefs-client", :require => 'mogilefs'
gem "mogile_image_store", :path => './'

group :development, :test do
  gem "sqlite3-ruby"
  gem "mysql2"
  gem "rspec", "~> 2.5"
  gem "rspec-rails"
  gem "factory_girl", "~> 1.3.2"
  gem "cover_me"
  gem "bundler"
  gem "jeweler"
  gem "capybara"
  gem "rdoc"
  gem "database_cleaner"
  gem 'acts_as_paranoid', :github => 'goncalossilva/rails3_acts_as_paranoid', :branch => 'rails3.2'
  if RUBY_VERSION >= '1.9'
    gem "ruby-debug19"
  else
    gem "ruby-debug"
  end
end

