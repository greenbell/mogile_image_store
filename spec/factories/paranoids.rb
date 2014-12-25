# coding: utf-8

FactoryGirl.define do
  sequence :paranoid_name do |n|
    "Paranoid Test #{n}"
  end

  factory :paranoid do
    name { FactoryGirl.generate(:paranoid_name) }
  end
end

