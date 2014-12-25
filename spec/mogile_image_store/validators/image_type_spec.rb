# coding: utf-8
require 'spec_helper'

describe MogileImageStore do
  context "Validators" do
    context "ImageType" do
      describe "with jpeg validation" do
        before{ @image = ImageJpeg.new }
        it "should accept jpeg image" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'sample.jpg',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.jpg")
          })
          expect(@image.valid?).to be_truthy
        end

        it "should not accept gif image" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'sample.gif',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.gif")
          })
          expect(@image.valid?).to be_falsey
        end

        it "should not accept png image" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'sample.png',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.png")
          })
          expect(@image.valid?).to be_falsey
        end
      end

      describe "with gif validation" do
        before{ @image = ImageGif.new }
        it "should not accept jpeg image" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'sample.jpg',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.jpg")
          })
          expect(@image.valid?).to be_falsey
        end

        it "should accept gif image" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'sample.gif',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.gif")
          })
          expect(@image.valid?).to be_truthy
        end

        it "should not accept png image" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'sample.png',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.png")
          })
          expect(@image.valid?).to be_falsey
        end
      end

      describe "with png validation" do
        before{ @image = ImagePng.new }
        it "should not accept jpeg image" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'sample.jpg',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.jpg")
          })
          expect(@image.valid?).to be_falsey
        end

        it "should not accept gif image" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'sample.gif',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.gif")
          })
          expect(@image.valid?).to be_falsey
        end

        it "should accept png image" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'sample.png',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.png")
          })
          expect(@image.valid?).to be_truthy
        end
      end

      describe "with jpeg|png validation" do
        before{ @image = ImageJpegPng.new }
        it "should accept jpeg image" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'sample.jpg',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.jpg")
          })
          expect(@image.valid?).to be_truthy
        end

        it "should not accept gif image" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'sample.gif',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.gif")
          })
          expect(@image.valid?).to be_falsey
        end

        it "should accept png image" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'sample.png',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.png")
          })
          expect(@image.valid?).to be_truthy
        end
      end

      describe "with old form image validation" do
        before{ @image = ImageJpegOldForm.new }
        it "should accept jpeg image" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'sample.jpg',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.jpg")
          })
          expect(@image.valid?).to be_truthy
        end

        it "should not accept text file" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'spec_helper.rb',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../spec_helper.rb")
          })
          expect(@image.valid?).to be_falsey
        end
      end

      describe "with error message of image validation" do
        before{ @image = ImageJpeg.new }
        it "should not accept text file" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'spec_helper.rb',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../spec_helper.rb")
          })
          expect(@image.valid?).to be_falsey
          expect(@image.errors[:image].shift).to eq('must be image file.')
        end
      end

      describe "with ja error message of image validation" do
        before do
          @image = ImageJpegPng.new
          I18n.locale = :ja
        end

        after do
          I18n.locale = I18n.default_locale
        end

        it "should not accept gif file" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'sample.gif',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.gif")
          })
          expect(@image.valid?).to be_falsey
          expect(@image.errors[:image].shift).to eq('はJPEG,PNGファイルでなければなりません。')
        end
      end

      describe "with custom error message of image validation" do
        before{ @image = ImageJpegCustomMsg.new }
        it "should not accept gif file" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'sample.gif',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.gif")
          })
          expect(@image.valid?).to be_falsey
          expect(@image.errors[:image].shift).to eq('custom')
        end
      end
    end
  end
end

