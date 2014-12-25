# coding: utf-8

FactoryGirl.define do
  sequence :confirm_name do |n|
    "ConfirmTest #{n}"
  end

  factory :confirm do
    name { FactoryGirl.generate(:confirm_name) }
  end
end

