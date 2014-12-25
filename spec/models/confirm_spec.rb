require 'spec_helper'

describe Confirm, :mogilefs => true do
  before(:all) do
    @prev_cache_time = MogileImageStore.options[:upload_cache]
    MogileImageStore.options[:upload_cache] = 1
  end
  after(:all) do
    MogileImageStore.options[:upload_cache] = @prev_cache_time
  end

  before do
    @mg = MogileFS::MogileFS.new({ :domain => MogileImageStore.backend['domain'], :hosts  => MogileImageStore.backend['hosts'] })
    @confirm = Factory.build(:confirm)
  end

  context "saving" do
    it "should return hash value when saved" do
      @confirm.set_image_file :image, "#{File.dirname(__FILE__)}/../sample.jpg"
      expect(@confirm.valid?).to be_truthy
      expect(@confirm.image).to eq('bcadded5ee18bfa7c99834f307332b02.jpg')
      expect(@mg.list_keys('').shift).to eq(['bcadded5ee18bfa7c99834f307332b02.jpg'])
      expect(MogileImage.find_by_name('bcadded5ee18bfa7c99834f307332b02').refcount).to eq(0)
      expect(MogileImage.find_by_name('bcadded5ee18bfa7c99834f307332b02').keep_till).not_to be_nil
      sleep(1)
      expect{ @confirm.save! }.not_to raise_error
      expect(@confirm.image).to eq('bcadded5ee18bfa7c99834f307332b02.jpg')
      expect(MogileImage.find_by_name('bcadded5ee18bfa7c99834f307332b02').refcount).to eq(1)
    end

    it "should increase refcount when saving the same image" do
      @confirm.set_image_file :image, "#{File.dirname(__FILE__)}/../sample.jpg"
      @confirm.save!
      @confirm = Factory.build(:confirm)
      expect(MogileImage.find_by_name('bcadded5ee18bfa7c99834f307332b02').refcount).to eq(1)
      @confirm.set_image_file :image, "#{File.dirname(__FILE__)}/../sample.jpg"
      expect(@confirm.valid?).to be_truthy
      expect(@mg.list_keys('').shift).to eq(['bcadded5ee18bfa7c99834f307332b02.jpg'])
      expect(MogileImage.find_by_name('bcadded5ee18bfa7c99834f307332b02').refcount).to eq(1)
      expect(MogileImage.find_by_name('bcadded5ee18bfa7c99834f307332b02').keep_till).not_to be_nil
      expect{ @confirm.save! }.not_to raise_error
      expect(@confirm.image).to eq('bcadded5ee18bfa7c99834f307332b02.jpg')
      expect(MogileImage.find_by_name('bcadded5ee18bfa7c99834f307332b02').refcount).to eq(2)
    end

    it "should not be valid when upload cache was cleared" do
      @confirm.set_image_data :image, File.open("#{File.dirname(__FILE__)}/../sample.png").read
      expect(@confirm.valid?).to be_truthy
      expect(MogileImage.find_by_name('60de57a8f5cd0a10b296b1f553cb41a9').refcount).to eq(0)
      expect(MogileImage.find_by_name('60de57a8f5cd0a10b296b1f553cb41a9').keep_till).not_to be_nil
      sleep(1)
      MogileImage.cleanup_temporary_image
      expect(@confirm.valid?).to be_falsey
      expect(@confirm.errors[:image]).to eq(["has expired. Please upload again."])
      expect(@confirm.image).to be_nil
      expect(MogileImage.find_by_name('60de57a8f5cd0a10b296b1f553cb41a9')).to be_nil
    end

    it "should accept another image using set_image_data" do
      @confirm.set_image_data :image, File.open("#{File.dirname(__FILE__)}/../sample.png").read
      sleep(1)
      MogileImage.cleanup_temporary_image
      @confirm = Factory.build(:confirm)
      @confirm.set_image_data :image, File.open("#{File.dirname(__FILE__)}/../sample.png").read
      expect(@confirm.valid?).to be_truthy
      expect(@confirm.image).to eq('60de57a8f5cd0a10b296b1f553cb41a9.png')
      expect(@mg.list_keys('').shift.sort).to eq(['60de57a8f5cd0a10b296b1f553cb41a9.png'])
      expect(MogileImage.find_by_name('60de57a8f5cd0a10b296b1f553cb41a9').refcount).to eq(0)
      expect(MogileImage.find_by_name('60de57a8f5cd0a10b296b1f553cb41a9').keep_till).not_to be_nil
      expect{ @confirm.save! }.not_to raise_error
      expect(@confirm.image).to eq('60de57a8f5cd0a10b296b1f553cb41a9.png')
      expect(MogileImage.find_by_name('60de57a8f5cd0a10b296b1f553cb41a9').refcount).to eq(1)
    end
  end

  context "overwriting" do
    it "should delete old image when overwritten" do
      @confirm.set_image_file :image, "#{File.dirname(__FILE__)}/../sample.png"
      @confirm.save!
      sleep(1)
      @confirm.set_image_file :image, "#{File.dirname(__FILE__)}/../sample.gif"
      expect(@confirm.valid?).to be_truthy
      expect(@confirm.image).to eq('5d1e43dfd47173ae1420f061111e0776.gif')
      expect(MogileImage.find_by_name('60de57a8f5cd0a10b296b1f553cb41a9').refcount).to eq(1)
      expect(MogileImage.find_by_name('5d1e43dfd47173ae1420f061111e0776').refcount).to eq(0)
      expect{ @confirm.save }.not_to raise_error
      expect(@confirm.image).to eq('5d1e43dfd47173ae1420f061111e0776.gif')
      expect(MogileImage.find_by_name('60de57a8f5cd0a10b296b1f553cb41a9')).to be_nil
      expect(MogileImage.find_by_name('5d1e43dfd47173ae1420f061111e0776').refcount).to eq(1)
      expect(@mg.list_keys('').shift.sort).to eq(
        ['5d1e43dfd47173ae1420f061111e0776.gif']
      )
    end
  end

  context "saving without uploading image" do
    it "should preserve image name" do
      @confirm.set_image_file :image, "#{File.dirname(__FILE__)}/../sample.gif"
      @confirm.save
      new_name = @confirm.name + ' new'
      @confirm.name = new_name
      expect(@confirm.valid?).to be_truthy
      expect(@confirm.name).to eq(new_name)
      expect(@confirm.image).to eq('5d1e43dfd47173ae1420f061111e0776.gif')
      expect(MogileImage).not_to receive(:commit_image)
      expect{ @confirm.save }.not_to raise_error
      expect(@confirm.name).to eq(new_name)
      expect(@confirm.image).to eq('5d1e43dfd47173ae1420f061111e0776.gif')
      expect(@mg.list_keys('').shift.sort).to eq(['5d1e43dfd47173ae1420f061111e0776.gif'])
      expect(MogileImage.find_by_name('5d1e43dfd47173ae1420f061111e0776').refcount).to eq(1)
    end
  end

  context "deletion" do
    it "should keep record with refcount = 0 when deleting non-expired image" do
      @confirm.set_image_file :image, "#{File.dirname(__FILE__)}/../sample.gif"
      @confirm.save
      expect{ @confirm.destroy }.not_to raise_error
      expect(@mg.list_keys('').shift.sort).to eq(['5d1e43dfd47173ae1420f061111e0776.gif'])
      expect(MogileImage.find_by_name('5d1e43dfd47173ae1420f061111e0776').refcount).to eq(0)
    end

    it "should delete image data when expired" do
      @confirm.set_image_file :image, "#{File.dirname(__FILE__)}/../sample.gif"
      @confirm.save
      @confirm.destroy
      sleep(1)
      MogileImage.cleanup_temporary_image
      expect(@mg.list_keys('')).to be_nil
      expect(MogileImage.all).to eq([])
    end
  end
end
