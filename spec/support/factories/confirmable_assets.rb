# coding: utf-8

Factory.sequence :confirmable_asset_name do |n|
  "ConfirmableAssetTest #{n}"
end

Factory.define :confirmable_asset do |f|
  f.name { Factory.next(:confirmable_asset_name) }
end

