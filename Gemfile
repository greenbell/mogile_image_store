source 'https://rubygems.org'

if ENV['RAILS_VER'] == '3.0'
  gem "rails", "~> 3.0.0"
  gem "mysql2", "~> 0.2.0"
else
  gem "rails", "~> 3.0"
  gem "mysql2"
end

if ENV['PARANOID'] == 'original'
  gem 'acts_as_paranoid'
else
  gem 'rails3_acts_as_paranoid', :git => 'git://github.com/mshibuya/rails3_acts_as_paranoid.git'
end

gem "rmagick", :require => false
gem "mogilefs-client", :require => 'mogilefs'
gem "mogile_image_store", :path => './'

group :development, :test do
  gem "sqlite3-ruby"
  gem "rspec-rails"
  gem "factory_girl", "~> 1.3.2"
  gem "cover_me"
  gem "bundler"
  gem "jeweler"
  gem "capybara"
  gem "rdoc"
  gem "database_cleaner"
  gem "debugger"
end
