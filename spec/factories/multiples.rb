# coding: utf-8

FactoryGirl.define do
  sequence :multiple_name do |n|
    "Test #{n}"
  end

  factory :multiple do
    title { FactoryGirl.generate(:multiple_name) }
  end
end

