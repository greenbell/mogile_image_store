# coding: utf-8

require 'digest/md5'
require 'digest/sha1'
require 'mime/types'
require 'mogilefs'
require 'net/http'
require 'RMagick'

##
# == 概要
# 添付画像をMogileFSに格納するプラグイン
#
module MogileImageStore
  require 'mogile_image_store/engine'

  mattr_accessor :backend, :options

  # 設定を読み込む
  def self.configure
    begin
      backend = MogileImageStore::Engine.config.mogile_fs[Rails.env]
    rescue NoMethodError
      backend = {}
    end
    if backend['mount_at']
      backend['mount_at'] += '/' if backend['mount_at'][-1] != '/'
    end
    if backend['base_url']
      backend['base_url'] += '/' if backend['base_url'][-1] != '/'
    else
      backend['base_url'] = '/image/'
    end

    MogileImageStore.backend = HashWithIndifferentAccess.new(backend)
    MogileImageStore.options = HashWithIndifferentAccess.
      new((MogileImageStore::Engine.config.options rescue {}))
  end

  # 認証キーを計算する
  def self.auth_key(path)
    Digest::SHA1.hexdigest(path + ':' + backend['secret'])
  end

  class ImageNotFound    < StandardError; end
  class SizeNotAllowed   < StandardError; end
  class ColumnNotFound   < StandardError; end
  class InvalidImage     < StandardError; end
  class UnsupportedImage < StandardError; end

  # 認証キーがセットされるHTTPリクエストヘッダ
  AUTH_HEADER = 'X-MogileImageStore-Auth'
  # 認証キーがセットされるHTTPリクエストヘッダに対応する環境変数名
  AUTH_HEADER_ENV = 'HTTP_X_MOGILEIMAGESTORE_AUTH'
  TO_EXTENSION = {'JPEG' => 'jpg', 'GIF' => 'gif', 'PNG' => 'png'}.freeze
  TO_FORMAT = TO_EXTENSION.invert.freeze


  autoload :ActiveRecord,   'mogile_image_store/active_record'
  autoload :Attachment,     'mogile_image_store/attachment'
  autoload :FormBuilder,    'mogile_image_store/form_helper'
  autoload :ImageDeletable, 'mogile_image_store/image_deletable'
  autoload :TagHelper,      'mogile_image_store/tag_helper'
  autoload :UrlHelper,      'mogile_image_store/url_helper'
  autoload :Validators,     'mogile_image_store/validators'

end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Base.class_eval { include MogileImageStore::ActiveRecord }
end
ActiveSupport.on_load(:action_controller) do
  ActionController::Base.class_eval { include MogileImageStore::ImageDeletable }
end
ActiveSupport.on_load(:action_view) do
  ActionView::Base.send(:include, MogileImageStore::TagHelper)
  ActionView::Helpers::FormBuilder.send(:include, MogileImageStore::FormBuilder)
end
ActiveSupport.on_load(:after_initialize) do
  MogileImageStore.configure
end

Dir[File.join("#{File.dirname(__FILE__)}/../config/locales/*.yml")].each do |locale|
  I18n.load_path.unshift(locale)
end

