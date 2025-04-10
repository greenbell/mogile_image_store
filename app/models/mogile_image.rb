# coding: utf-8

class MogileImage < ApplicationRecord
  extend MogileImageStore::UrlHelper

  before_destroy :purge_stored_content

  class << self
    def save_image(attachment, options = {})
      find_or_initialize_by_name(attachment.name).
        send(options.delete(:temporary) ? :store_temporarily : :store, attachment)
    end
    ##
    # Persists image data and returns the key
    #
    def store_image(data, options={})
      save_image(MogileImageStore::Attachment.new(data, options).preprocess!, options)
    end
    ##
    # Persists data and returns the key
    #
    def store_attachment(data, options={})
      save_image(MogileImageStore::Attachment.new(data, options), options)
    end


    ##
    # 確認画面経由で一時保存されているデータを確定
    #
    def commit_image(key)
      return unless key.is_a?(String) && !key.empty?
      name, ext = key.split('.')
      self.transaction do
        record = find_by_name name
        raise MogileImageStore::ImageNotFound unless record
        record.refcount += 1
        if record.keep_till && record.keep_till < Time.now
          record.keep_till = nil
        end
        record.save!
      end
    end

    ##
    # 指定されたハッシュ値を持つレコードを削除し、
    # 同時にMogileFSからリサイズ分も含めその画像を削除する。
    #
    def destroy_image(key)
      return unless key.is_a?(String) && !key.empty?
      name, ext = key.split('.')
      self.transaction do
        record = find_by_name name
        return unless record
        record.purge
      end
      cleanup_temporary_image
    end
    ##
    # 指定されたキーを持つ画像のURLをMogileFSより取得して返す。
    # X-REPROXY-FORヘッダでの出力に使う。
    #
    def fetch_urls(name, format, size='raw')
      [mime_type_for(format), retrieve_image(name, format, size) {|mg,key| mg.get_paths key }]
    end

    ##
    # 指定されたキーを持つ画像のデータを取得して返す。
    #
    def fetch_data(name, format, size='raw')
      [mime_type_for(format), retrieve_image(name, format, size) {|mg,key| mg.get_file_data key }]
    end

    ##
    # 保存期限を過ぎた一時データを消去する
    #
    def cleanup_temporary_image
      self.transaction do
        self.where('keep_till < ?', Time.now).all.each do |record|
          if record.refcount > 0
            record.keep_till = nil
            record.save!
          else
            record.purge
          end
        end
      end
    end

    def key_exist?(key)
      key = Array.wrap(key).uniq
      names = key.map{|k| k.split('.').first }
      key.count == where(:name => names).count
    end

    def mogilefs_connection
      @@mogilefs ||= MogileFS::MogileFS.new({
        :domain => MogileImageStore.backend['domain'],
        :hosts  => MogileImageStore.backend['hosts'],
        :timeout => MogileImageStore.backend['timeout'] || 3
      })
    end

    def mime_type_for(format)
      MIME::Types.type_for(format.to_s).first
    end

    protected

    ##
    # パラメータからMogileFSのキーを生成し、引数で受け取ったブロックに渡す
    #
    def retrieve_image(name, format, size, &block)
      record = find_by_name(name)
      raise MogileImageStore::ImageNotFound unless record

      # check whether size is allowd
      raise MogileImageStore::SizeNotAllowed unless size_allowed?(size)

      if record.resize_needed_for? format, size
        key = "#{name}.#{format}/#{size}"
      else
        #needs no resizing
        key = "#{name}.#{format}"
      end
      mg = mogilefs_connection
      begin
        return block.call(mg, key)
      rescue MogileFS::Backend::UnknownKeyError
        # 画像がまだ生成されていないので生成する
        begin
          img = Magick::Image.from_blob(mg.get_file_data(record.filename)).shift
        rescue MogileFS::Backend::UnknownKeyError
          raise MogileImageStore::ImageNotFound
        end
        mg.store_content key, MogileImageStore.backend['class'], resize_image(img, format, size).to_blob
      end
      return block.call(mg, key)
    end

    ##
    # 画像をリサイズ・変換
    #
    def resize_image(img, format, size)
      w, h, method, n = size.scan(/(\d+)x(\d+)([a-z]*)(\d*)/).shift
      w, h, n = [w, h, n].map {|i| i.to_i if i }
      case method
      when 'fill'
        img = resize_with_fill(img, w, h, n, 'black')
      when 'fillw'
        img = resize_with_fill(img, w, h, n, 'white')
      else
        if size != 'raw' && (img.columns > w || img.rows > h)
          img.resize_to_fit! w, h
        end
      end
      new_format = MogileImageStore::TO_FORMAT[format.to_s]
      img.format = new_format if img.format != new_format
      img
    end
    ##
    # 画像を背景色つきでリサイズ
    #
    def resize_with_fill(img, w, h, n, color)
      n ||= 0
      img.resize_to_fit! w-n*2, h-n*2
      background = Magick::Image.new(w, h)
      background.background_color = color
      background.composite(img, Magick::CenterGravity, Magick::OverCompositeOp)
    end

    ##
    # 画像サイズが許可されているかどうか判定
    #
    def size_allowed?(size)
      MogileImageStore.options[:allowed_sizes].each do |item|
        if item.is_a? Regexp
          return true if size.match(item)
        else
          return true if size == item
        end
      end
      return false
    end
  end

  def filename
    name + '.' + image_type
  end

  def purge
    if refcount > 1
      self.refcount -= 1
      save!
    else
      if keep_till && keep_till > Time.now
        self.refcount = 0
        save!
      else
        destroy
      end
    end
  end

  ##
  # Tells if resizing is needed for given format and size
  #
  def resize_needed_for?(format, size)
    return false if size == 'raw'

    # 加工が指定されているなら必要
    w, h, method = size.scan(/(\d+)x(\d+)([a-z]*\d*)/).shift
    return true if method && !method.empty?

    # オリジナルの画像サイズと比較
    w, h =  [w, h].map{|i| i.to_i}
    begin
      if w > width && h > height
        false
      else
        true
      end
    rescue => e
      Rails.logger.info e
      Rails.logger.info "force resize by mogile_image_store"
      true
    end
  end

  def store(attachment)
    if persisted?
      self.refcount += 1
    else
      self.refcount = 1
      attachment.persist(self)
    end
    save!
    filename
  end

  def store_temporarily(attachment)
    unless persisted?
      self.refcount = 0
      attachment.persist(self)
    end
    self.keep_till = Time.now + (MogileImageStore.options[:upload_cache] || 3600)
    save!
    filename
  end

  private

  def purge_stored_content
    mg = self.class.mogilefs_connection
    urls = []
    mg.each_key(name) do |k|
      mg.delete k
      url = parse_key k
      urls.push(url) if url
    end
    if urls.size > 0 && MogileImageStore.backend['reproxy']
      base = URI.parse(MogileImageStore.backend['base_url'])
      if MogileImageStore.backend['perlbal']
        host, port = MogileImageStore.backend['perlbal'].split(':')
        port ||= 80
      else
        host, port = [base.host, base.port]
      end
      # Request asynchronously
      t = Thread.new(host, port, base, urls.join(' ')) do |conn_host, conn_port, perlbal, body|
        Net::HTTP.start(conn_host, conn_port) do |http|
          http.post(perlbal.path + 'flush', body, {
            MogileImageStore::AUTH_HEADER => MogileImageStore.auth_key(body),
            'Host' => perlbal.host + (perlbal.port != 80 ? ':' + perlbal.port.to_s : ''),
          })
        end
      end
    end
  end
  ##
  # Creates URL from MogileFS key
  # (For reproxy cache clear)
  #
  def parse_key(key)
    name, format, size = key.scan(/([0-9a-f]{32})\.([^\/]+)(?:\/(\d+x\d+[a-z]*\d*))?/).shift
    size ||= 'raw'
    base = URI.parse(MogileImageStore.backend['base_url'])
    base.path + size + '/' + name + '.' + format
  end
end
