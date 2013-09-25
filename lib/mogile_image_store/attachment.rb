# encoding: utf-8
require 'digest/md5'

module MogileImageStore
  class Attachment
    attr_reader :options, :content, :size, :type, :width, :height

    def initialize(data, options={})
      @options = options.symbolize_keys
      @content = data
      @size = @content.size
      @type = options[:type].try(:to_sym)
    end

    def attributes
      {:size       => size,
       :image_type => extension,
       :width      => width,
       :height     => height}
    end

    def extension
      type && MogileImageStore::TYPE_TO_EXT[type.upcase]
    end

    def image?
      !!extension
    end

    def name
      Digest::MD5.hexdigest(content)
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
      if resize || strip
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
      @type = img.format.to_sym
      @width = img.columns
      @height = img.rows
      self
    end
  end
end
