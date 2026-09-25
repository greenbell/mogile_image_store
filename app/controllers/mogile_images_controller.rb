# coding: utf-8

class MogileImagesController < ActionController::Base
  protect_from_forgery :except => [:flush, :show]

  rescue_from MogileImageStore::ImageNotFound, :with => :error_404
  rescue_from MogileImageStore::SizeNotAllowed, :with => :error_404
  before_action :verify_origin_secret, :only => :show

  ##
  # 画像の送信、もしくはx-reproxy-cache-forヘッダ出力を行う
  #
  def show
    if MogileImageStore.backend['reproxy']
      type, urls = MogileImage.fetch_urls(params[:name], params[:format], params[:size])
      response.header['Content-Type'] = type.to_s
      response.header['X-REPROXY-URL'] = urls.join(' ')
      if MogileImageStore.backend['cache']
        response.header['X-REPROXY-CACHE-FOR'] = "#{MogileImageStore.backend['cache']}; Content-Type"
      end
      head :ok
    else
      type, data = MogileImage.fetch_data(params[:name], params[:format], params[:size])
      response.header['Content-Type'] = type.to_s
      # v2: CloudFront の「S3 に無いとき」の元として返すときに、S3 に置いた物と同じキャッシュ指定にする
      if (cache_control = MogileImageStore.backend['serve_cache_control']).present?
        response.header['Cache-Control'] = cache_control
        response.header['Access-Control-Allow-Origin'] = '*'
      end
      render plain: data, layout: false, content_type: type
    end
  end

  ##
  # reproxyが有効の際にreproxy cacheのクリアを行う
  #
  def flush
    unless MogileImageStore.backend['reproxy'] && MogileImageStore.backend['cache']
      head :no_content
      return
    end

    body = request.body.read
    # authentication
    if request.env[MogileImageStore::AUTH_HEADER_ENV] == MogileImageStore.auth_key(body)
      response.header['X-REPROXY-CACHE-CLEAR'] = body
      head :ok
    else
      head :unauthorized
    end
  end

  def error_404
    head :not_found
  end

  private

  ##
  # v2: CloudFront の元(origin_mount_at)として来た要求は、CloudFront が付ける秘密のヘッダを確かめる。
  # mogile_fs.yml の origin_secret が空なら確かめない(ローカル・試験用)
  def verify_origin_secret
    origin_at = MogileImageStore.backend['origin_mount_at']
    return unless origin_at && request.path.start_with?(origin_at)
    secret = MogileImageStore.backend['origin_secret']
    return if secret.blank?
    head :forbidden unless ActiveSupport::SecurityUtils.secure_compare(request.headers['X-Origin-Verify'].to_s, secret.to_s)
  end
end
