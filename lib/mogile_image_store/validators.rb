# encoding: utf-8

module MogileImageStore
  module Validators
    extend ActiveSupport::Concern
    ##
    # Validates image attributes.
    # ==== example:
    #   validates :image, :image_attribute => { :type => [:jpg, :png] }
    #   validates :image, :image_attribute => { :type => [:jpg, :png], :type_message => 'jpeg or png' }
    #   validates :image, :image_attribute => { :type => :jpg, :maxsize = 500.kilobytes, :minwidth => 200, :minheight => 200 }
    #   validates :image, :image_attribute => { :type => :jpg, :width => 500, :height => 420 }
    #   
    #   validates_image_attribute_of :image, :type => :jpg, :width => 500, :height => 420
    # 
    class ImageAttributeValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        return unless value.is_a? MogileImageStore::Attachment
        if options[:type]
          allowed = Array.wrap(options[:type]).map(&:to_s)
          unless allowed.include?(value.extension)
            record.errors[attribute] << (
              options[:type_message] ||
              I18n.translate('mogile_image_store.errors.messages.must_be_image_type', :type => allowed.map{|t| MogileImageStore::TO_FORMAT[t]}.join(','))
            )
          end
        end
        if options[:maxsize]
          if value.size > options[:maxsize]
            record.errors[attribute] << (
              options[:size_message] ||
              I18n.translate('mogile_image_store.errors.messages.size_smaller', :size => options[:maxsize]/1024)
            )
          end
        end
        if options[:minsize]
          if value.size < options[:minsize]
            record.errors[attribute] << (
              options[:size_message] ||
              I18n.translate('mogile_image_store.errors.messages.size_larger', :size => options[:minsize]/1024)
            )
          end
        end
        if options[:maxwidth]
          if value.width > options[:maxwidth]
            record.errors[attribute] << (
              options[:width_message] ||
              I18n.translate('mogile_image_store.errors.messages.width_smaller', :width => options[:maxwidth])
            )
          end
        end
        if options[:minwidth]
          if value.width < options[:minwidth]
            record.errors[attribute] << (
              options[:width_message] ||
              I18n.translate('mogile_image_store.errors.messages.width_larger', :width => options[:minwidth])
            )
          end
        end
        if options[:width]
          if value.width != options[:width]
            record.errors[attribute] << (
              options[:width_message] ||
              I18n.translate('mogile_image_store.errors.messages.width', :width => options[:width])
            )
          end
        end
        if options[:maxheight]
          if value.height > options[:maxheight]
            record.errors[attribute] << (
              options[:height_message] ||
              I18n.translate('mogile_image_store.errors.messages.height_smaller', :height => options[:maxheight])
            )
          end
        end
        if options[:minheight]
          if value.height < options[:minheight]
            record.errors[attribute] << (
              options[:height_message] ||
              I18n.translate('mogile_image_store.errors.messages.height_larger', :height => options[:minheight])
            )
          end
        end
        if options[:height]
          if value.height != options[:height]
            record.errors[attribute] << (
              options[:height_message] ||
              I18n.translate('mogile_image_store.errors.messages.height', :height => options[:height])
            )
          end
        end
      end
    end

    ##
    # Validates attachment format.
    # ==== example:
    #   validates :asset, :attachment => { :type => [:pdf] }
    #
    class AttachmentValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        return unless value.is_a? MogileImageStore::Attachment
        if options[:type]
          allowed = Array.wrap(options[:type]).map(&:to_s)
          unless allowed.include?(value.extension)
            record.errors[attribute] << (
              options[:type_message] ||
              I18n.translate('mogile_image_store.errors.messages.must_be_image_type', :type => allowed.join(','))
            )
          end
        end
      end
    end

    module ClassMethods
      def validates_image_attribute_of(*attr_names)
        validates_with ImageAttributeValidator, _merge_attributes(attr_names)
      end

      def validates_attachment_attribute_of(*attr_names)
        validates_with ImageAttributeValidator, _merge_attributes(attr_names)
      end
    end
  end
end
