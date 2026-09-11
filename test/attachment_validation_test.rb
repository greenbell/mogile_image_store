require 'minitest/autorun'
require 'rails'
require 'active_record'
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'mogile_image_store'

class AttachmentValidationTest < Minitest::Test
  Model = Struct.new(:attachment) do
    def image_columns; [:image]; end
    def attachment_cache; { image: attachment }; end
    def errors; @errors ||= ActiveModel::Errors.new(self); end
  end

  def setup
    @previous_options = MogileImageStore.options
    MogileImageStore.options = { maxsize: 1024 }
  end

  def teardown
    MogileImageStore.options = @previous_options
  end

  def test_supported_four_character_extensions_are_preserved
    { 'cover.webp' => 'webp', 'cover.WEBP' => 'webp', 'cover.avif' => 'avif',
      'cover.jpg' => 'jpg', 'cover.svg' => 'svg', 'cover.unknown' => 'bin' }.each do |filename, extension|
      assert_equal extension, MogileImageStore::Attachment.new('data', filename: filename).extension
    end
  end

  def test_invalid_image_errors_are_added_on_rails_seven
    model = Model.new(MogileImageStore::Attachment.new('not an image', filename: 'cover.webp'))
    validate(model)
    refute_empty model.errors[:image]
  end

  def test_oversized_images_are_rejected
    image = Magick::Image.new(12, 8)
    image.format = 'WEBP'
    model = Model.new(MogileImageStore::Attachment.new(image.to_blob))
    MogileImageStore.options[:maxsize] = 1
    validate(model)
    refute_empty model.errors[:image]
  ensure
    image&.destroy!
  end

  private

  def validate(model)
    MogileImageStore::ActiveRecord::Shared.instance_method(:validate_images).bind_call(model)
  end
end
