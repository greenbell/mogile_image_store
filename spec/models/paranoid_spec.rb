require 'spec_helper'

describe Paranoid, :mogilefs => true do
  before do
    @mg = MogileFS::MogileFS.new({ :domain => MogileImageStore.backend['domain'], :hosts  => MogileImageStore.backend['hosts'] })
  end

  context "saving" do
    before do
      @paranoid = Factory.build(:paranoid)
    end

    it "should return hash value when saved" do
      @paranoid.set_image_file :image, "#{File.dirname(__FILE__)}/../sample.jpg"
      expect{ @paranoid.save }.not_to raise_error
      expect(@paranoid.image).to eq('bcadded5ee18bfa7c99834f307332b02.jpg')
      expect(@mg.list_keys('').shift).to eq(['bcadded5ee18bfa7c99834f307332b02.jpg'])
    end

    it "should accept another image using set_image_data" do
      @paranoid.set_image_file :image, "#{File.dirname(__FILE__)}/../sample.jpg"
      @paranoid.save!
      @paranoid = Factory.build(:paranoid)
      @paranoid.set_image_data :image, File.open("#{File.dirname(__FILE__)}/../sample.png").read
      expect{ @paranoid.save }.not_to raise_error
      expect(@paranoid.image).to eq('60de57a8f5cd0a10b296b1f553cb41a9.png')
      expect(@mg.list_keys('').shift.sort).to eq(['60de57a8f5cd0a10b296b1f553cb41a9.png', 'bcadded5ee18bfa7c99834f307332b02.jpg'])
      expect(MogileImage.find_by_name('bcadded5ee18bfa7c99834f307332b02').refcount).to eq(1)
      expect(MogileImage.find_by_name('60de57a8f5cd0a10b296b1f553cb41a9').refcount).to eq(1)
    end
  end

  context "deletion" do
    before do
      @paranoid = Factory.build(:paranoid)
      @paranoid.set_image_file :image, "#{File.dirname(__FILE__)}/../sample.jpg"
      @paranoid.save!
    end

    it "should affect nothing on soft removal" do
      expect{ @paranoid.destroy }.not_to raise_error
      expect(@mg.list_keys('').shift.sort).to eq(['bcadded5ee18bfa7c99834f307332b02.jpg'])
      expect(MogileImage.find_by_name('bcadded5ee18bfa7c99834f307332b02').refcount).to eq(1)
    end

    it "should decrease refcount when deleting duplicated image" do
      expect do
        @paranoid.destroy
        @paranoid.reload.destroy
      end.not_to raise_error
      expect(@mg.list_keys('')).to be_nil
      expect(MogileImage.find_by_name('bcadded5ee18bfa7c99834f307332b02')).to be_nil
    end

    it "should delete image data on real removal" do
      expect{ @paranoid.destroy! }.not_to raise_error
      expect(@mg.list_keys('')).to be_nil
      expect(MogileImage.find_by_name('bcadded5ee18bfa7c99834f307332b02')).to be_nil
    end
  end
end
