Rails.application.routes.draw do
  begin
    mount_at = MogileImageStore.backend['mount_at']

    if mount_at
      get "#{mount_at}:size/:name.:format", :to => "mogile_images#show", :constraints => {
        :size => /(raw|\d+x\d+[a-z]*\d*)/,
        :name =>/[0-9a-f]{0,32}/,
        :format =>/(\w+)/,
      }
      post "#{mount_at}flush", :to => "mogile_images#flush"
    end

    delete ':controller/:id/image_delete/:column', :action => 'image_delete'
  rescue NoMethodError
    #do nothing
  end
end
