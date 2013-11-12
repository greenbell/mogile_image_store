# encoding: utf-8

module MogileImageStore
  class Attachment
    attr_reader :options, :content, :name, :size, :extension, :width, :height

    def initialize(data, options={})
      @options = options.symbolize_keys
      @content = data
      @name = Digest::MD5.hexdigest(data)
      @size = @content.size
      @extension = extension_for(options[:filename] || '')
    end

    def attributes
      {:size       => size,
       :image_type => extension,
       :width      => width,
       :height     => height}
    end

    def extension_for(filename)
      (MIME::Types.type_for(filename).first || MIME::Type.new('application/octet-stream')).
        extensions.find{|e| e.length <= 3} || 'bin'
    end

    def persist(mogile_image)
      mogile_image.attributes = attributes
      MogileImage.mogilefs_connection.store_content mogile_image.filename, MogileImageStore.backend['class'], content
    end

    def preprocess!
      imglist = ::Magick::ImageList.new
      begin
        imglist.from_blob(@content)
      rescue
        raise InvalidImage
      end
      if (filter = ::MogileImageStore.options[:image_filter]) && filter.is_a?(Proc)
        filter.call(imglist)
      end
      resize = false
      resize = true if ::MogileImageStore.options[:maxwidth] &&
          imglist.first.columns > ::MogileImageStore.options[:maxwidth].to_i
      resize = true if ::MogileImageStore.options[:maxheight] &&
          imglist.first.columns > ::MogileImageStore.options[:maxheight].to_i

      strip = (!options[:keep_exif] &&
                  imglist.inject([]){|r,i| r.concat(i.get_exif_by_entry()) }.any?)
      if filter || resize || strip
        if resize
          imglist.each do |i|
            i.resize_to_fit!(MogileImageStore.options[:maxwidth],
                             MogileImageStore.options[:maxheight])
          end
        end
        if strip
          # strip exif info
          imglist.each{|i| i.strip! }
        end
        @content = imglist.to_blob
      end
      img = imglist.first
      @size = content.size
      @extension = TO_EXTENSION[img.format.to_s] or raise UnsupportedImage
      @width = img.columns
      @height = img.rows
      self
    end
  end
end
