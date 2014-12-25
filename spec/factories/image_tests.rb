# coding: utf-8

FactoryGirl.define do
  sequence :image_test_name do |n|
    "Test #{n}"
  end

  factory :image_test do
    name { FactoryGirl.generate(:image_test_name) }
  end

  factory :keep_exif do
    name { FactoryGirl.generate(:image_test_name) }
  end
end

