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

        self.image_columns.each do |column|
          define_method("#{column}=") do |value|
            if value.is_a?(ActionDispatch::Http::UploadedFile) || value.is_a?(MogileImageStore::Attachment)
              attachment_cache[column.to_sym] = value
            else
              attachment_cache.delete(column.to_sym) if defined?(@attachment_cache) && @attachment_cache
              write_attribute(column, value)
            end
          end

          define_method(column) do
            if defined?(@attachment_cache) && @attachment_cache && @attachment_cache.key?(column.to_sym)
              @attachment_cache[column.to_sym]
            else
              read_attribute(column)
            end
          end
        end

        include MogileImageStore::ActiveRecord::Shared
        include MogileImageStore::Validators
        if image_options[:confirm]
          include MogileImageStore::ActiveRecord::Confirmable
        else
          include MogileImageStore::ActiveRecord::Direct
        end
      end
      alias :has_attachment :has_attachments

      def has_images(columns='image', options={})
        has_attachments columns, options.symbolize_keys

        validate :validate_images
      end
      alias :has_image :has_images
    end

    module Shared
      extend ActiveSupport::Concern

      included do
        before_validation :parse_attachments
        after_destroy :destroy_attachments
      end

      def set_image_file(column, path)
        public_send("#{column}=", ActionDispatch::Http::UploadedFile.new({
          :filename => File.basename(path),
          :tempfile => File.open(path)
        }))
      end

      def set_image_data(column, data)
        public_send("#{column}=", ActionDispatch::Http::UploadedFile.new({
          :tempfile => StringIO.new(data)
        }))
      end

      def attachment_cache
        @attachment_cache ||= {}
      end

      private

      def parse_attachments
        image_columns.each do |c|
          attachment = attachment_cache[c] || read_attribute(c)

          if attachment.is_a?(ActionDispatch::Http::UploadedFile)
            attachment_cache[c] = MogileImageStore::Attachment.new(
              attachment.read, :filename => attachment.original_filename, :keep_exif => image_options[:keep_exif]
            )
          end
        end
      end

      def validate_images
        image_columns.each do |column|
          attachment = attachment_cache[column] || self[column]
          case attachment
          when MogileImageStore::Attachment
            if attachment.size > MogileImageStore.options[:maxsize]
              errors.add(column,
                I18n.translate('mogile_image_store.errors.messages.size_smaller', :size => MogileImageStore.options[:maxsize]/1024))
            end

            begin
              attachment.preprocess!
            rescue MogileImageStore::InvalidImage
              errors.add(column, I18n.translate('mogile_image_store.errors.messages.must_be_image'))
            rescue MogileImageStore::UnsupportedImage
              errors.add(column, I18n.translate('mogile_image_store.errors.messages.must_be_valid_type'))
            end
          end
        end
      end

      def destroy_attachments
        image_columns.each do |c|
          MogileImage.destroy_image(self[c]) if self[c] && destroyed? && frozen?
        end
      end
    end

    module Direct
      extend ActiveSupport::Concern

      included do
        before_save :save_attachments
      end

      def save_attachments
        image_columns.each do |c|
          attachment = attachment_cache[c] || read_attribute(c)

          if attachment.is_a?(ActionDispatch::Http::UploadedFile)
            attachment = MogileImageStore::Attachment.new(
              attachment.read, :type => attachment.content_type, :keep_exif => self.image_options[:keep_exif]
            )
          elsif !attachment.is_a?(MogileImageStore::Attachment)
            next
          end

          prev_image = self.send(c.to_s+'_was')
          if prev_image.is_a?(String) && !prev_image.empty?
            MogileImage.destroy_image(prev_image)
          end

          write_attribute(c, MogileImage.save_image(attachment))
          attachment_cache.delete(c)
        end
      end
    end

    module Confirmable
      extend ActiveSupport::Concern

      included do
        after_validation :temporarily_save_attachments
        before_save      :commit_attachments
        validate         :validate_attachments_for_confirmation
      end

      def temporarily_save_attachments
        if errors.empty?
          image_columns.each do |column|
            attachment = attachment_cache[column] || self[column]
            next unless attachment.is_a? MogileImageStore::Attachment
            saved_key = MogileImage.save_image(attachment, :temporary => true)
            write_attribute(column, saved_key)
            attachment_cache.delete(column)
          end
        end
      end

      def commit_attachments
        image_columns.each do |c|
          next if !self[c] || !self.send(c.to_s + '_changed?')
          prev_image = self.send(c.to_s+'_was')
          if prev_image.is_a?(String) && prev_image.present?
            MogileImage.destroy_image(prev_image)
          end
          MogileImage.commit_image(self[c])
        end
      end

      def validate_attachments_for_confirmation
        image_columns.each do |column|
          if self[column].is_a?(String) && self[column].present? && self.send(column.to_s + '_changed?')
            unless MogileImage.key_exist?(self[column])
              # the attachment with given key no longer exists
              errors.add(column, I18n.translate('mogile_image_store.errors.messages.cache_expired'))
              self[column] = nil
            end
          end
        end
      end
    end
  end
end
