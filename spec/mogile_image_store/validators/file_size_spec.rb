# coding: utf-8
require 'spec_helper'

describe MogileImageStore do
  context "Validators" do
    context "FileSize" do
      describe "with <=20k validation" do
        before{ @image = ImageMax20.new }
        it "should accept 16k image" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'sample.png',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.png")
          })
          expect(@image.valid?).to be_truthy
        end

        it "should not accept 30k image" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'sample.gif',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.gif")
          })
          expect(@image.valid?).to be_falsey
        end
      end

      describe "with >=20k validation" do
        before{ @image = ImageMin20.new }
        it "should not accept 16k image" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'sample.png',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.png")
          })
          expect(@image.valid?).to be_falsey
        end

        it "should accept 30k image" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'sample.gif',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.gif")
          })
          expect(@image.valid?).to be_truthy
        end
      end

      describe "with 20k-40k validation" do
        before{ @image = ImageMin20Max40.new }
        it "should not accept 16k image" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'sample.png',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.png")
          })
          expect(@image.valid?).to be_falsey
        end

        it "should accept 30k image" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'sample.gif',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.gif")
          })
          expect(@image.valid?).to be_truthy
        end

        it "should not accept 97k image" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'sample.jpg',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.jpg")
          })
          expect(@image.valid?).to be_falsey
        end
      end

      describe "with <=20k validation of old form" do
        before{ @image = ImageMax20OldForm.new }
        it "should accept 16k image" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'sample.png',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.png")
          })
          expect(@image.valid?).to be_truthy
        end

        it "should not accept 30k image" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'sample.gif',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.gif")
          })
          expect(@image.valid?).to be_falsey
        end
      end

      describe "with error message of <=20k validation" do
        before{ @image = ImageMax20.new }
        it "should not accept 30k image" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'sample.gif',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.gif")
          })
          expect(@image.valid?).to be_falsey
          expect(@image.errors[:image].shift).to eq('must be smaller than 20KB.')
        end
      end

      describe "with ja error message of <=20k validation" do
        before do
          @image = ImageMax20.new
          I18n.locale = :ja
        end

        after do
          I18n.locale = I18n.default_locale
        end

        it "should not accept 30k image" do
          @image.image = ActionDispatch::Http::UploadedFile.new({
            filename: 'sample.gif',
            tempfile: File.open("#{File.dirname(__FILE__)}/../../sample.gif")
          })
          expect(@image.valid?).to be_falsey
          expect(@image.errors[:image].shift).to eq('は20KB以下でなければなりません。')
        end
      end

      describe "with custom error message of <=20k validation" do
        before{ @image = ImageMax20CustomMsg.new }
        it "should not accept 30k image" do
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

