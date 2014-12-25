# coding: utf-8

FactoryGirl.define do
  sequence :confirmable_asset_name do |n|
    "ConfirmableAssetTest #{n}"
  end

  factory :confirmable_asset do
    name { FactoryGirl.generate(:confirmable_asset_name) }
  end
end

