# coding: utf-8

Factory.sequence :asset_test_name do |n|
  "Asset #{n}"
end

Factory.define :asset_test do |f|
  f.name { Factory.next(:asset_test_name) }
end

