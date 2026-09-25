require 'minitest/autorun'
require 'rails'
require 'active_record'
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'mogile_image_store'
require 'mogile_image_store/storage/mirror'

# MogileFS の台帳にはあるのに実体が消えた物(全部の置き場所が 404)を、mirror が「無い」と同じに扱うこと
class MirrorLostFileTest < Minitest::Test
  LOST = 'all paths failed with GET: http://10.200.0.222:7500/dev123/0/008/801/0008801347.fid - Not Found (Net::HTTPNotFound), ' \
         'http://10.200.0.223:7500/dev124/0/008/801/0008801347.fid - Not Found (Net::HTTPNotFound)'
  TIMEOUT = 'all paths failed with GET: http://10.200.0.222:7500/dev123/0/008/801/0008801347.fid - Not Found (Net::HTTPNotFound), ' \
            'http://10.200.0.223:7500/dev124/0/008/801/0008801347.fid - read timed out (Timeout::Error)'

  class Store
    attr_reader :stored
    def initialize(data: {}, error: nil)
      @data = data; @error = error; @stored = {}
    end

    def get_file_data(key)
      raise @error if @error
      @data.fetch(key) { raise ::MogileFS::Backend::UnknownKeyError, "unknown_key #{key}" }
    end

    def store_content(key, _klass, content)
      @stored[key] = content
    end
  end

  def setup
    @previous_backend = MogileImageStore.backend
    MogileImageStore.backend = { 'class' => 'image' }
  end

  def teardown
    MogileImageStore.backend = @previous_backend
  end

  def test_s3_first_and_lost_in_mogilefs_is_treated_as_missing
    mirror = MogileImageStore::Storage::Mirror.new(mogilefs: Store.new(error: ::MogileFS::Error.new(LOST)), s3: Store.new, read: :s3)
    assert_raises(::MogileFS::Backend::UnknownKeyError) { mirror.get_file_data('a.jpg/300x300fill') }
  end

  def test_mogilefs_first_and_lost_reads_s3_and_heals_mogilefs
    mogile = Store.new(error: ::MogileFS::Error.new(LOST))
    mirror = MogileImageStore::Storage::Mirror.new(mogilefs: mogile, s3: Store.new(data: { 'a.jpg' => 'DATA' }), read: :mogilefs)
    assert_equal 'DATA', mirror.get_file_data('a.jpg')
    assert_equal({ 'a.jpg' => 'DATA' }, mogile.stored, 'S3 から読めた物は MogileFS に写し直す')
  end

  def test_other_mogilefs_errors_are_not_hidden
    mirror = MogileImageStore::Storage::Mirror.new(mogilefs: Store.new(error: ::MogileFS::Error.new(TIMEOUT)), s3: Store.new, read: :s3)
    error = assert_raises(::MogileFS::Error) { mirror.get_file_data('a.jpg') }
    refute_kind_of ::MogileFS::Backend::UnknownKeyError, error
  end

  def test_found_on_primary_is_unchanged
    mirror = MogileImageStore::Storage::Mirror.new(mogilefs: Store.new, s3: Store.new(data: { 'a.jpg' => 'S3' }), read: :s3)
    assert_equal 'S3', mirror.get_file_data('a.jpg')
  end
end
