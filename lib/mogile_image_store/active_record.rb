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

        prepend MogileImageStore::ActiveRecord::Shared
        include MogileImageStore::Validators
        if image_options[:confirm]
          include MogileImageStore::ActiveRecord::Confirmable
        else
          include MogileImageStore::ActiveRecord::Direct
        end

        after_destroy :destroy_attachments

        mod = Module.new
        image_columns.each do |column|
          mod.module_eval <<-EOS, __FILE__, __LINE__ + 1
            def #{column}
              #{column}_before_type_cast
            end

            def #{column}=(value)
              if value.is_a? ActionDispatch::Http::UploadedFile
                super MogileImageStore::Attachment.new(
                  value.read, :filename => value.original_filename, :keep_exif => image_options[:keep_exif])
              else
                super
              end
            end
          EOS
        end
        prepend mod
      end
      alias :has_attachment :has_attachments

      def has_images(columns='image', options={})
        has_attachments columns, options.symbolize_keys

        validate :validate_images
      end
      alias :has_image :has_images
    end

    module Shared
      def set_image_file(column, path)
        self[column] = ActionDispatch::Http::UploadedFile.new({
          filename: File.basename(path),
          tempfile: File.open(path)
        })
      end

      def set_image_data(column, data)
        self[column] = ActionDispatch::Http::UploadedFile.new({
          tempfile: StringIO.new(data)
        })
      end

      def each_attachment
        image_columns.each do |column|
          yield column, send(column)
        end
      end

      def write_attribute(attr, value)
        if value.is_a?(ActionDispatch::Http::UploadedFile) && image_columns.include?(attr.to_sym)
          send(:"#{attr}=", value)
        else
          super
        end
      end

      private

      def validate_images
        each_attachment do |column, attachment|
          case attachment
          when MogileImageStore::Attachment
            if attachment.size > MogileImageStore.options[:maxsize]
              errors[column] <<
                I18n.translate('mogile_image_store.errors.messages.size_smaller', size: MogileImageStore.options[:maxsize]/1024)
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

      def destroy_attachments
        each_attachment do |column, attachment|
          MogileImage.destroy_image(attachment) if attachment && destroyed? && frozen?
        end
      end
    end

    module Direct
      extend ActiveSupport::Concern

      included do
        before_save :save_attachments
      end

      def save_attachments
        each_attachment do |column, attachment|
          next if !attachment.is_a?(MogileImageStore::Attachment)
          prev_image = send(:"#{column}_was")
          if prev_image.is_a?(String) && prev_image.present?
            MogileImage.destroy_image(prev_image)
          end
          self[column] = MogileImage.save_image(attachment)
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
          each_attachment do |column, attachment|
            next unless attachment.is_a? MogileImageStore::Attachment
            self[column] = MogileImage.save_image(attachment, temporary: true)
          end
        end
      end

      def commit_attachments
        each_attachment do |column, attachment|
          next if !attachment || !send(:"#{column}_changed?")
          prev_image = send(:"#{column}_was")
          if prev_image.is_a?(String) && prev_image.present?
            MogileImage.destroy_image(prev_image)
          end
          MogileImage.commit_image(attachment)
        end
      end

      def validate_attachments_for_confirmation
        each_attachment do |column, attachment|
          if attachment.is_a?(String) && attachment.present? && send(column.to_s + '_changed?')
            unless MogileImage.key_exist?(attachment)
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
