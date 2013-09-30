class ConfirmableAsset < ActiveRecord::Base
  has_attachment :asset, :confirm => true
end
