# coding: utf-8

module MogileImageStore
  ##
  # included to ActiveRecord::Base
  #
  module ActiveRecord # :nodoc:
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
    end

    module ClassMethods
      ##
      # Sets callbacks for images/attachments persistence
      #
      # ==== columns
      # Array of column names to which attachment keys are saved.
      # Columns should be created as string type, and optionally :limit=>36.
      #
      # ==== Options
      # Following opitons are avaliable.
      # =====:confirm
      # Enables confirmation mode.
      # =====:keep_exif
      # If set to true, Exif information is preserved on save.
      # (striped by default)
      #
      # ==== Examples
      #   has_images
      #   has_images :logo
      #   has_images ['banner1', 'banner2'], :confirm => true
      #
      def has_attachments(columns=nil, options={})
        cattr_accessor  :image_columns, :image_options
        raise "has_attachments / has_images can't be called more than once." if image_columns || image_options

        self.image_columns = Array.wrap(columns || 'attachment').map{|item| item.to_sym }
        self.image_options = options.symbolize_keys

        class_eval do
          include MogileImageStore::ActiveRecord::Shared
          if image_options[:confirm]
            include MogileImageStore::ActiveRecord::Confirmable
          else
            include MogileImageStore::ActiveRecord::Direct
          end

          before_validation do
            image_columns.each do |c|
              if self[c].is_a? ActionDispatch::Http::UploadedFile
                self[c] = MogileImageStore::Attachment.new(
                  self[c].read, :filename => self[c].original_filename, :keep_exif => image_options[:keep_exif])
              end
            end
          end

          after_destroy do
            image_columns.each do |c|
              MogileImage.destroy_image(self[c]) if self[c] && destroyed? && frozen?
            end
          end
        end
      end
      alias :has_attachment :has_attachments

      def has_images(columns='image', options={})
        has_attachments columns, options.symbolize_keys
        class_eval do
          include MogileImageStore::ValidatesImageAttribute
          validate :validate_images
        end
      end
      alias :has_image :has_images
    end

    module Shared
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
      # Image validation
      #
      def validate_images
        image_columns.each do |column|
          attachment = self[column]
          case attachment
          when MogileImageStore::Attachment
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
          end
        end
      end
    end

    module Direct
      extend ActiveSupport::Concern

      included do
        before_save do
          image_columns.each do |c|
            next if !self[c]

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
    end

    module Confirmable
      extend ActiveSupport::Concern

      included do
        after_validation do
          if errors.empty?
            image_columns.each do |column|
              next unless self[column].is_a? MogileImageStore::Attachment
              self[column] = MogileImage.save_image(self[column], :temporary => true)
            end
          end
        end

        before_save do
          image_columns.each do |c|
            next if !self[c]

            # with confirmation: image is already saved
            next unless self.send(c.to_s + '_changed?')
            prev_image = self.send(c.to_s+'_was')
            if prev_image.is_a?(String) && !prev_image.empty?
              MogileImage.destroy_image(prev_image)
            end
            MogileImage.commit_image(self[c])
          end
        end

        validate do
          image_columns.each do |column|
            attachment = self[column]
            if attachment.is_a? String
              if image_options[:confirm] && !self[column].empty? && self.send(column.to_s + '_changed?')
                unless MogileImage.key_exist?(self[column])
                  # the attachment with given key no longer exists
                  errors[column] << I18n.translate('mogile_image_store.errors.messages.cache_expired')
                  self[column] = nil
                end
              end
            end
          end
        end
      end
    end
  end
end
