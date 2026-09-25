Rails.application.routes.draw do
  begin
    mount_at = MogileImageStore.backend['mount_at']

    if mount_at
      match "#{mount_at}:size/:name.:format", :to => "mogile_images#show", :via => 'get', :constraints => {
        :size => /(raw|\d+x\d+[a-z]*\d*)/,
        :name =>/[0-9a-f]{0,32}/,
        :format =>/(\w+)/,
      }
      match "#{mount_at}flush", :to => "mogile_images#flush", :via => 'post'
    end

    # v2: CloudFront の「S3 に無いとき」の元。CloudFront Function が URL を S3 のキーの形
    # (/<name>.<format>[/<size>]、MogileFS のキーと同じ)に書き換えてから来る。
    # mogile_fs.yml に origin_mount_at(例 /_image_origin/)を書いたときだけ有効
    origin_at = MogileImageStore.backend['origin_mount_at']
    if origin_at
      match "#{origin_at}:name.:format(/:size)", :to => "mogile_images#show", :via => [:get, :head],
        :defaults => { :size => 'raw' }, :as => :mogile_image_origin, :constraints => {
          :size => /(raw|\d+x\d+[a-z]*\d*)/,
          :name => /[0-9a-f]{32}/,
          :format => /\w+/,
        }
    end

    match ':controller/:id/image_delete/:column', :action => 'image_delete', :via => [:get, :post]
  rescue NoMethodError
    #do nothing
  end
end
