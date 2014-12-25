# coding: utf-8
require 'spec_helper'

describe MogileImageStore::Validators::AttachmentValidator do
  context "with txt validation" do
    before{ @asset = AttachmentTypeTxt.new }
    it "should accept txt file" do
      @asset.asset = ActionDispatch::Http::UploadedFile.new({
        filename: 'sample.txt',
        tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.txt")
      })
      expect(@asset.valid?).to be_truthy
    end

    it "should not accept jpg file" do
      @asset.asset = ActionDispatch::Http::UploadedFile.new({
        filename: 'sample.jpg',
        tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.jpg")
      })
      expect(@asset.valid?).to be_falsey
    end
  end

  describe "with ja error message of image validation" do
    before do
      @asset = AttachmentTypeTxt.new
      I18n.locale = :ja
    end

    after do
      I18n.locale = I18n.default_locale
    end

    it "should not accept gif file" do
      @asset.asset = ActionDispatch::Http::UploadedFile.new({
        filename: 'sample.jpg',
        tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.jpg")
      })
      expect(@asset.valid?).to be_falsey
      expect(@asset.errors[:asset].shift).to eq('はtxtファイルでなければなりません。')
    end
  end
end
