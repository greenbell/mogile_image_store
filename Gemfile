source 'https://rubygems.org'

if ENV['RAILS_VER'] == '3.0'
  gem "rails", "~> 3.0.0"
  gem "mysql2", "~> 0.2.0"
else
  gem "rails", ">= 7.1.1"
  gem "mysql2"
end

if ENV['PARANOID'] == 'original'
  gem 'acts_as_paranoid'
else
  gem 'rails3_acts_as_paranoid', :git => 'git://github.com/mshibuya/rails3_acts_as_paranoid.git'
end

gemspec
