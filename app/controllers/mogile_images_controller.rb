# coding: utf-8

class MogileImagesController < ActionController::Base
  protect_from_forgery :except => [:flush]

  rescue_from MogileImageStore::ImageNotFound, :with => :error_404
  rescue_from MogileImageStore::SizeNotAllowed, :with => :error_404

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
end
