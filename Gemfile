source 'https://rubygems.org'

if ENV['RAILS_VER'] == '3.2'
  gem "rails", "~> 3.2"
  gem 'rails3_acts_as_paranoid', github: 'mshibuya/rails3_acts_as_paranoid'
elsif ENV['RAILS_VER'] == '4.1'
  gem "rails", "~> 4.1.0"
  gem 'acts_as_paranoid', '>= 0.5.0.beta1'
else
  gem "rails", "~> 4.2.0"
  gem 'acts_as_paranoid', github: 'ActsAsParanoid/acts_as_paranoid'
end
gem "mysql2"

gem 'byebug', :platforms => :mri_21

gemspec
