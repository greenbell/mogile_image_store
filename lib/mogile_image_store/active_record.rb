# coding: utf-8

require 'RMagick'

module MogileImageStore
  ##
  # == 概要
  # ActiveRecord::Baseを拡張するモジュール
  #
  module ActiveRecord # :nodoc:
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
    end
    #
    # ActiveRecord::Baseにextendされるモジュール
    #
    module ClassMethods
      ##
      # 画像保存用のコールバックを設定する。
      #
      # ==== columns
      # 画像が保存されるカラム名を指定。データ型は :string, :limit=>36を使用。
      # 省略時のカラム名はimageとなる。
      #
      # ==== options
      # 以下のオプションがある。
      # =====:confirm
      # trueにするとvalidationの時点で画像を仮保存するようになる。
      # 確認画面を挟む場合に使用。
      # =====:keep_exif
      # trueにするとこのモデルに保存される画像はexif情報を残すようになる。
      # （デフォルトでは消去）
      #
      # ==== 例:
      #   has_images
      #   has_images :logo
      #   has_images ['banner1', 'banner2']
      #
      def has_attachments(columns=nil, options={})
        cattr_accessor  :image_columns, :image_options

        self.image_columns = Array.wrap(columns || 'image').map!{|item| item.to_sym }
        self.image_options = options.symbolize_keys

        class_eval <<-EOV
        include MogileImageStore::ActiveRecord::InstanceMethods

        before_validation :parse_attachments
        before_save       :save_attachments
        after_destroy     :destroy_attachments
        EOV
      end
      alias :has_attachment :has_attachments

      def has_images(columns=nil, options={})
        has_attachments columns, options.symbolize_keys.merge(:image => true)
        class_eval <<-EOV
        include MogileImageStore::ValidatesImageAttribute
        validate :validate_images
        EOV
      end
      alias :has_image :has_images
    end
    #
    # 各モデルにincludeされるモジュール
    #
    module InstanceMethods
      ##
      # 画像ファイルをセットするためのメソッド。
      # formからのアップロード時以外に画像を登録する際などに使用。
      #
      def set_image_file(column, path)
        self[column] = ActionDispatch::Http::UploadedFile.new({
          :filename => File.basename(path),
          :tempfile => File.open(path)
        })
      end

      ##
      # 画像データをファイルを経由せず直接セットするためのメソッド。
      #
      def set_image_data(column, data)
        self[column] = ActionDispatch::Http::UploadedFile.new({
          :tempfile => StringIO.new(data)
        })
      end

      private

      ##
      # Hooked on before_validation
      #
      def parse_attachments
        image_columns.each do |c|
          if image_options[:confirm] && self[c].is_a?(String) &&
             !self[c].empty? && self.send(c.to_s + '_changed?')
            # 確認経由でセットされたキーがまだ存在するかどうかチェック
            if !MogileImage.key_exist?(self[c])
              errors[c] << I18n.translate('mogile_image_store.errors.messages.cache_expired')
              self[c] = nil
            end
          else
            next unless self[c].is_a?(ActionDispatch::Http::UploadedFile)
            self[c] = MogileImageStore::Attachment.new(
              self[c].read, :filename => self[c].original_filename, :keep_exif => self.image_options[:keep_exif])
          end
        end
      end

      ##
      # Hooked on before_save
      #
      def save_attachments
        image_columns.each do |c|
          next if !self[c]
          
          if image_options[:confirm]
            # with confirmation: image is already saved
            next unless self.send(c.to_s + '_changed?')
            prev_image = self.send(c.to_s+'_was')
            if prev_image.is_a?(String) && !prev_image.empty?
              MogileImage.destroy_image(prev_image)
            end
            MogileImage.commit_image(self[c])
          else
            # no confirmation
            if self[c].is_a?(ActionDispatch::Http::UploadedFile)
              self[c] = MogileImageStore::Attachment.new(
                self[c].read, :type => self[c].content_type, :keep_exif => self.image_options[:keep_exif])
            elsif !self[c].is_a?(MogileImageStore::Attachment)
              next
            end
            prev_image = self.send(c.to_s+'_was')
            if prev_image.is_a?(String) && !prev_image.empty?
              MogileImage.destroy_image(prev_image)
            end
            self[c] = MogileImage.save_image(self[c])
          end
        end
      end
      ##
      # Hooked on after_destroy
      #
      def destroy_attachments
        image_columns.each do |c|
          MogileImage.destroy_image(self[c]) if self[c] && destroyed? && frozen?
        end
      end

      ##
      # Image validation
      #
      def validate_images
        image_columns.each do |column|
          attachment = self[column]
          next unless attachment.is_a?(MogileImageStore::Attachment)
          if attachment.size > MogileImageStore.options[:maxsize]
            errors[column] <<
              I18n.translate('mogile_image_store.errors.messages.size_smaller', :size => MogileImageStore.options[:maxsize]/1024)
          end

          begin
            attachment.preprocess!
          rescue MogileImageStore::InvalidImage
            errors[column] << I18n.translate('mogile_image_store.errors.messages.must_be_image')
          rescue MogileImageStore::UnsupportedImage
            errors[column] << I18n.translate('mogile_image_store.errors.messages.must_be_valid_type')
          end

          # 確認ありの時はこの時点で仮保存
          if errors.empty? && image_options[:confirm]
            self[column] = MogileImage.save_image(attachment, :temporary => true)
          end
        end
      end
    end
  end
end

