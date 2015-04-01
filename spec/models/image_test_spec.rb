require 'spec_helper'

describe ImageTest do
  context "default validation" do
    before{ @image_test = ImageTest.new }

    it "should not accept file larger than maxsize" do
      t = Tempfile.new('mogileimagetest')
      for i in 1..(1.megabytes)
        t << 'abcde'
      end
      t << 'f'
      expect(t.size).to eq(5.megabytes+1)
      @image_test.set_image_file :image, t
      expect(@image_test.valid?).to be_falsey
      expect(@image_test.errors[:image]).to include("must be smaller than 5120KB.")
    end

    context 'receive a file which is larger than mazsize before resize' do
      before :all do
        @large_file = Tempfile.new('mogileimagetest')
        @large_file.binmode
        1.megabytes.times { @large_file << "\0" * 5 }
      end

      before { @image_test.set_image_file :image, @large_file }

      it 'should not change the result of valid?' do
        expect(@image_test.valid?).to eq @image_test.valid?
      end

      it 'should not accept' do
       expect(@image_test.valid?).to be_falsey
      end
    end

    it "should accept jpeg image" do
      @image_test.image = ActionDispatch::Http::UploadedFile.new({
        filename: 'sample.jpg',
        tempfile: File.open("#{File.dirname(__FILE__)}/../sample.jpg")
      })
      expect(@image_test.valid?).to be_truthy
    end

    it "should accept gif image" do
      @image_test.image = ActionDispatch::Http::UploadedFile.new({
        filename: 'sample.gif',
        tempfile: File.open("#{File.dirname(__FILE__)}/../sample.gif")
      })
      expect(@image_test.valid?).to be_truthy
    end

    it "should accept png image" do
      @image_test.image = ActionDispatch::Http::UploadedFile.new({
        filename: 'sample.png',
        tempfile: File.open("#{File.dirname(__FILE__)}/../sample.png")
      })
      expect(@image_test.valid?).to be_truthy
    end

     it "should not accept bmp image" do
      @image_test.image = ActionDispatch::Http::UploadedFile.new({
        filename: 'sample.bmp',
        tempfile: File.open("#{File.dirname(__FILE__)}/../sample.bmp")
      })
      expect(@image_test.valid?).to be_falsey
      expect(@image_test.errors[:image].shift).to eq("must be JPEG, GIF or PNG file.")
    end

    it "should not accept text file" do
      @image_test.image = ActionDispatch::Http::UploadedFile.new({
        filename: 'spec_helper.rb',
        tempfile: File.open("#{File.dirname(__FILE__)}/../spec_helper.rb")
      })
      expect(@image_test.valid?).to be_falsey
      expect(@image_test.errors[:image].shift).to eq("must be image file.")
    end

    describe "when maxwidth and maxheight is nil" do
      before do
        @maxwidth_bak = MogileImageStore.options[:maxwidth]
        @maxheight_bak = MogileImageStore.options[:maxheight]
        MogileImageStore.options[:maxwidth] = nil
        MogileImageStore.options[:maxwidth] = nil
      end
      after do
        MogileImageStore.options[:maxwidth] = @maxwidth_bak
        MogileImageStore.options[:maxheight] = @maxheight_bak
      end
      it "should not raise error" do
        @image_test.image = ActionDispatch::Http::UploadedFile.new({
          filename: 'sample.jpg',
          tempfile: File.open("#{File.dirname(__FILE__)}/../sample.jpg")
        })
        expect{ @image_test.valid? }.not_to raise_error
      end
    end
  end

  context "MogileFS backend", mogilefs: true do
    before do
      @mg = MogileFS::MogileFS.new({ domain: MogileImageStore.backend['domain'], hosts: MogileImageStore.backend['hosts'] })
    end

    context "saving" do
      before do
        @image_test = FactoryGirl.build(:image_test)
      end

      it "should return hash value when saved" do
        @image_test.set_image_file :image, "#{File.dirname(__FILE__)}/../sample.jpg"
        expect{ @image_test.save }.not_to raise_error
        expect(@image_test.image).to eq('bcadded5ee18bfa7c99834f307332b02.jpg')
        expect(@mg.list_keys('').shift).to eq(['bcadded5ee18bfa7c99834f307332b02.jpg'])
      end

      it "should increase refcount when saving the same image" do
        @image_test.set_image_file :image, "#{File.dirname(__FILE__)}/../sample.jpg"
        @image_test.save!
        @image_test = FactoryGirl.build(:image_test)
        expect(MogileImage.find_by_name('bcadded5ee18bfa7c99834f307332b02').refcount).to eq(1)
        @image_test.set_image_file :image, "#{File.dirname(__FILE__)}/../sample.jpg"
        expect{ @image_test.save }.not_to raise_error
        expect(@image_test.image).to eq('bcadded5ee18bfa7c99834f307332b02.jpg')
        expect(@mg.list_keys('').shift).to eq(['bcadded5ee18bfa7c99834f307332b02.jpg'])
        expect(MogileImage.find_by_name('bcadded5ee18bfa7c99834f307332b02').refcount).to eq(2)
      end
    end

    context "retrieval" do
      before do
        @image_test = FactoryGirl.build(:image_test)
        @image_test.set_image_file :image, "#{File.dirname(__FILE__)}/../sample.jpg"
        @image_test.save!
        @image_test = FactoryGirl.build(:image_test)
        @image_test.set_image_file :image, "#{File.dirname(__FILE__)}/../sample.png"
        @image_test.save!
      end

      it "should return 2 urls" do
        sleep(3) # wait until replication becomes ready
        expect(MogileImage.fetch_urls('bcadded5ee18bfa7c99834f307332b02', 'jpg').pop.size).to eq(2)
      end

      it "should return raw jpeg image" do
        content_type, data = MogileImage.fetch_data('bcadded5ee18bfa7c99834f307332b02', 'jpg')
        expect(content_type).to eq('image/jpeg')
        img = ::Magick::Image.from_blob(data).shift
        expect(img.format).to eq('JPEG')
        expect(img.columns).to eq(725)
        expect(img.rows).to eq(544)
      end

      it "should return raw png image" do
        content_type, data = MogileImage.fetch_data('60de57a8f5cd0a10b296b1f553cb41a9', 'png')
        expect(content_type).to eq('image/png')
        img = ::Magick::Image.from_blob(data).shift
        expect(img.format).to eq('PNG')
        expect(img.columns).to eq(460)
        expect(img.rows).to eq(445)
      end

      it "should return jpeg=>png converted image" do
        content_type, data = MogileImage.fetch_data('bcadded5ee18bfa7c99834f307332b02', 'png')
        expect(content_type).to eq('image/png')
        img = ::Magick::Image.from_blob(data).shift
        expect(img.format).to eq('PNG')
        expect(img.columns).to eq(725)
        expect(img.rows).to eq(544)
        expect(@mg.list_keys('').shift.sort).to eq(
          ['60de57a8f5cd0a10b296b1f553cb41a9.png', 'bcadded5ee18bfa7c99834f307332b02.jpg', 'bcadded5ee18bfa7c99834f307332b02.png']
        )
      end

      it "should return resized jpeg image" do
        content_type, data = MogileImage.fetch_data('bcadded5ee18bfa7c99834f307332b02', 'jpg', '600x450')
        expect(content_type).to eq('image/jpeg')
        img = ::Magick::Image.from_blob(data).shift
        expect(img.format).to eq('JPEG')
        expect(img.columns).to eq(600)
        expect(img.rows).to eq(450)
        expect(@mg.list_keys('').shift.sort).to eq(
          ['60de57a8f5cd0a10b296b1f553cb41a9.png', 'bcadded5ee18bfa7c99834f307332b02.jpg',
           'bcadded5ee18bfa7c99834f307332b02.jpg/600x450']
        )
      end

      it "does not break when symbol is given as format" do
        content_type, data = MogileImage.fetch_data('bcadded5ee18bfa7c99834f307332b02', :jpg, '600x450')
        expect(content_type).to eq('image/jpeg')
        expect(@mg.list_keys('').shift.sort).to eq(
          ['60de57a8f5cd0a10b296b1f553cb41a9.png', 'bcadded5ee18bfa7c99834f307332b02.jpg',
           'bcadded5ee18bfa7c99834f307332b02.jpg/600x450']
        )
      end

      it "should return raw jpeg image when requested larger size" do
        content_type, data = MogileImage.fetch_data('bcadded5ee18bfa7c99834f307332b02', 'jpg', '800x600')
        expect(content_type).to eq('image/jpeg')
        img = ::Magick::Image.from_blob(data).shift
        expect(img.format).to eq('JPEG')
        expect(img.columns).to eq(725)
        expect(img.rows).to eq(544)
        expect(@mg.list_keys('').shift.sort).to eq(
          ['60de57a8f5cd0a10b296b1f553cb41a9.png', 'bcadded5ee18bfa7c99834f307332b02.jpg']
        )
      end

      it "should return filled jpeg image" do
        content_type, data = MogileImage.fetch_data('bcadded5ee18bfa7c99834f307332b02', 'jpg', '80x80fill')
        expect(content_type).to eq('image/jpeg')
        img = ::Magick::Image.from_blob(data).shift
        expect(img.format).to eq('JPEG')
        expect(img.columns).to eq(80)
        expect(img.rows).to eq(80)
        dark = ::Magick::Pixel.from_color('#070707').intensity
        expect(img.pixel_color(40, 0).intensity).to be < dark
        expect(img.pixel_color(40,79).intensity).to be < dark
        expect(img.pixel_color( 0,40).intensity).to be > dark
        expect(img.pixel_color(79,40).intensity).to be > dark
        expect(@mg.list_keys('').shift.sort).to eq(
          ['60de57a8f5cd0a10b296b1f553cb41a9.png', 'bcadded5ee18bfa7c99834f307332b02.jpg',
           'bcadded5ee18bfa7c99834f307332b02.jpg/80x80fill']
        )
      end

      it "should return filled jpeg image" do
        content_type, data = MogileImage.fetch_data('bcadded5ee18bfa7c99834f307332b02', 'jpg', '80x80fill2')
        expect(content_type).to eq('image/jpeg')
        img = ::Magick::Image.from_blob(data).shift
        expect(img.format).to eq('JPEG')
        expect(img.columns).to eq(80)
        expect(img.rows).to eq(80)
        dark = ::Magick::Pixel.from_color('#070707').intensity
        expect(img.pixel_color(40, 0).intensity).to be < dark
        expect(img.pixel_color(40,79).intensity).to be < dark
        expect(img.pixel_color( 0,40).intensity).to be < dark
        expect(img.pixel_color(79,40).intensity).to be < dark
        expect(img.pixel_color(40, 2).intensity).to be < dark
        expect(img.pixel_color(40,77).intensity).to be < dark
        expect(img.pixel_color( 2,40).intensity).to be > dark
        expect(img.pixel_color(77,40).intensity).to be > dark
        expect(@mg.list_keys('').shift.sort).to eq(
          ['60de57a8f5cd0a10b296b1f553cb41a9.png', 'bcadded5ee18bfa7c99834f307332b02.jpg',
           'bcadded5ee18bfa7c99834f307332b02.jpg/80x80fill2']
        )
      end

      it "should return filled jpeg image with white background" do
        content_type, data = MogileImage.fetch_data('bcadded5ee18bfa7c99834f307332b02', 'jpg', '80x80fillw')
        expect(content_type).to eq('image/jpeg')
        img = ::Magick::Image.from_blob(data).shift
        expect(img.format).to eq('JPEG')
        expect(img.columns).to eq(80)
        expect(img.rows).to eq(80)
        bright = ::Magick::Pixel.from_color('#F9F9F9').intensity
        expect(img.pixel_color(40, 0).intensity).to be > bright
        expect(img.pixel_color(40,79).intensity).to be > bright
        expect(img.pixel_color( 0,40).intensity).to be < bright
        expect(img.pixel_color(79,40).intensity).to be < bright
        expect(@mg.list_keys('').shift.sort).to eq(
          ['60de57a8f5cd0a10b296b1f553cb41a9.png', 'bcadded5ee18bfa7c99834f307332b02.jpg',
           'bcadded5ee18bfa7c99834f307332b02.jpg/80x80fillw']
        )
      end

      it "should raise error when size is not allowed" do
        expect{ MogileImage.fetch_urls('bcadded5ee18bfa7c99834f307332b02', 'jpg', '83x60') }.to raise_error MogileImageStore::SizeNotAllowed
        expect{ MogileImage.fetch_urls('bcadded5ee18bfa7c99834f307332b02', 'jpg', '80x60fill') }.to raise_error MogileImageStore::SizeNotAllowed
        expect{ MogileImage.fetch_urls('bcadded5ee18bfa7c99834f307332b02', 'jpg', '800x604') }.to raise_error MogileImageStore::SizeNotAllowed
      end

      it "should return existence of keys" do
        expect(MogileImage.key_exist?('60de57a8f5cd0a10b296b1f553cb41a9.png')).to be_truthy
        expect(MogileImage.key_exist?('5d1e43dfd47173ae1420f061111e0776.gif')).to be_falsey
        expect(MogileImage.key_exist?([
          '60de57a8f5cd0a10b296b1f553cb41a9.png',
          '60de57a8f5cd0a10b296b1f553cb41a9.png',
          'bcadded5ee18bfa7c99834f307332b02.jpg',
        ])).to be_truthy
        expect(MogileImage.key_exist?([
          '60de57a8f5cd0a10b296b1f553cb41a9.png',
          '5d1e43dfd47173ae1420f061111e0776.gif',
        ])).to be_falsey
      end
    end

    context "overwriting" do
      before do
        @image_test = FactoryGirl.build(:image_test)
        @image_test.set_image_file :image, "#{File.dirname(__FILE__)}/../sample.png"
        @image_test.save!
      end

      it "should delete old image when overwritten" do
        @image_test.set_image_file :image, "#{File.dirname(__FILE__)}/../sample.gif"
        expect{ @image_test.save }.not_to raise_error
        expect(@image_test.image).to eq('5d1e43dfd47173ae1420f061111e0776.gif')
        expect(@mg.list_keys('').shift.sort).to eq(['5d1e43dfd47173ae1420f061111e0776.gif'])
        expect(MogileImage.find_by_name('60de57a8f5cd0a10b296b1f553cb41a9')).to be_nil
        expect(MogileImage.find_by_name('5d1e43dfd47173ae1420f061111e0776').refcount).to eq(1)
      end
    end

    context "saving without uploading image" do
      before do
        @image_test = FactoryGirl.build(:image_test)
        @image_test.set_image_file :image, "#{File.dirname(__FILE__)}/../sample.jpg"
        @image_test.save!
      end

      it "should preserve image name" do
        new_name = @image_test.name + ' new'
        @image_test.name = new_name
        expect(MogileImage).not_to receive(:save_image)
        expect{ @image_test.save }.not_to raise_error
        expect(@image_test.name).to eq(new_name)
        expect(@image_test.image).to eq('bcadded5ee18bfa7c99834f307332b02.jpg')
        expect(@mg.list_keys('').shift.sort).to eq(['bcadded5ee18bfa7c99834f307332b02.jpg'])
        expect(MogileImage.find_by_name('bcadded5ee18bfa7c99834f307332b02').refcount).to eq(1)
      end

      it "should preserve image name with image_type validation" do
        @image_test = ImageTestWithImageType.first
        expect(@image_test.image).to eq('bcadded5ee18bfa7c99834f307332b02.jpg')
        new_name = @image_test.name + ' imagetype'
        expect(@image_test.valid?).to be_truthy
      end

      it "should preserve image name with file_size validation" do
        @image_test = ImageTestWithFileSize.first
        expect(@image_test.image).to eq('bcadded5ee18bfa7c99834f307332b02.jpg')
        new_name = @image_test.name + ' filesize'
        expect(@image_test.valid?).to be_truthy
      end

      it "should preserve image name with width validation" do
        @image_test = ImageTestWithWidth.first
        expect(@image_test.image).to eq('bcadded5ee18bfa7c99834f307332b02.jpg')
        new_name = @image_test.name + ' width'
        expect(@image_test.valid?).to be_truthy
      end

      it "should preserve image name with height validation" do
        @image_test = ImageTestWithHeight.first
        expect(@image_test.image).to eq('bcadded5ee18bfa7c99834f307332b02.jpg')
        new_name = @image_test.name + ' height'
        expect(@image_test.valid?).to be_truthy
      end
    end

    context "deletion" do
      before do
        @image_test = FactoryGirl.build(:image_test)
        @image_test.set_image_file :image, "#{File.dirname(__FILE__)}/../sample.jpg"
        @image_test.save!
        @image_test = FactoryGirl.build(:image_test)
        @image_test.set_image_file :image, "#{File.dirname(__FILE__)}/../sample.jpg"
        @image_test.save!
      end

      it "should decrease refcount when deleting duplicated image" do
        expect{ @image_test.destroy }.not_to raise_error
        expect(@mg.list_keys('').shift.sort).to eq(['bcadded5ee18bfa7c99834f307332b02.jpg'])
        expect(MogileImage.find_by_name('bcadded5ee18bfa7c99834f307332b02').refcount).to eq(1)
      end

      it "should delete image data when deleting image" do
        @image_test.destroy
        @image_test = ImageTest.first
        expect{ @image_test.destroy }.not_to raise_error
        expect(@mg.list_keys('')).to be_nil
        expect(MogileImage.find_by_name('bcadded5ee18bfa7c99834f307332b02')).to be_nil
      end
    end

    context "saving image without model" do
      it "should save image and return key" do
        key = MogileImage.store_image(File.open("#{File.dirname(__FILE__)}/../sample.png").read)
        expect(key).to eq('60de57a8f5cd0a10b296b1f553cb41a9.png')
        expect(@mg.list_keys('').shift).to eq(['60de57a8f5cd0a10b296b1f553cb41a9.png'])
      end

      it "should raise error with invalid data" do
        expect do
          MogileImage.store_image('abc')
        end.to raise_error MogileImageStore::InvalidImage
      end
    end

    context "jpeg exif" do
      it "should clear exif data" do
        @image_test = FactoryGirl.build(:image_test)
        @image_test.set_image_file :image, "#{File.dirname(__FILE__)}/../sample_exif.jpg"
        expect{ @image_test.save }.not_to raise_error
        content_type, data = MogileImage.fetch_data(@image_test.image.split('.').first, 'jpg', 'raw')
        imglist = Magick::ImageList.new
        imglist.from_blob(data)
        expect(imglist.first.get_exif_by_entry()).to eq([])
      end
      it "should keep exif data" do
        @image_test = FactoryGirl.build(:keep_exif)
        @image_test.set_image_file :image, "#{File.dirname(__FILE__)}/../sample_exif.jpg"
        expect{ @image_test.save }.not_to raise_error
        content_type, data = MogileImage.fetch_data(@image_test.image.split('.').first, 'jpg', 'raw')
        imglist = Magick::ImageList.new
        imglist.from_blob(data)
        expect(imglist.first.get_exif_by_entry()).not_to eq([])
      end
    end

    context "huge image" do
      it "should be shrinked to fit within limit" do
        @image_test = FactoryGirl.build(:image_test)
        @image_test.set_image_file :image, "#{File.dirname(__FILE__)}/../sample_huge.gif"
        expect{ @image_test.save }.not_to raise_error
        content_type, data = MogileImage.fetch_data(@image_test.image.split('.').first, 'jpg', 'raw')
        imglist = Magick::ImageList.new
        imglist.from_blob(data)
        expect(imglist.first.columns).to eq(2048)
        expect(imglist.first.rows).to eq(1536)
      end
    end

    context "filter" do
      before do
        MogileImageStore.options[:image_filter] = lambda{|imglist| imglist.format = 'png' }
        @image_test = FactoryGirl.build(:image_test)
      end

      after do
        MogileImageStore.options.delete :image_filter
      end

      it "should work" do
        @image_test.set_image_file :image, "#{File.dirname(__FILE__)}/../sample.jpg"
        expect{ @image_test.save }.not_to raise_error
        expect(@image_test.image).to eq('bcadded5ee18bfa7c99834f307332b02.png')
        expect(@mg.list_keys('').shift).to eq(['bcadded5ee18bfa7c99834f307332b02.png'])
      end
    end
  end
end
