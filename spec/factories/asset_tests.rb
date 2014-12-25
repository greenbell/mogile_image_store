# coding: utf-8

FactoryGirl.define do
  sequence :asset_test_name do |n|
    "Asset #{n}"
  end

  factory :asset_test do
    name { FactoryGirl.generate(:asset_test_name) }
  end
end

