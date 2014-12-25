require 'spec_helper'

describe Multiple, mogilefs: true do
  context "saving" do
    before do
      @multiple = FactoryGirl.build(:multiple)
    end

    it "should return hash value when saved" do
      @multiple.set_image_file :banner1, "#{File.dirname(__FILE__)}/../sample.jpg"
      @multiple.set_image_file :banner2, "#{File.dirname(__FILE__)}/../sample.png"
      expect{ @multiple.save! }.not_to raise_error
      expect(@multiple.banner1).to eq('bcadded5ee18bfa7c99834f307332b02.jpg')
      expect(@multiple.banner2).to eq('60de57a8f5cd0a10b296b1f553cb41a9.png')
      expect(@mg.list_keys('').shift.sort).to eq(['60de57a8f5cd0a10b296b1f553cb41a9.png', 'bcadded5ee18bfa7c99834f307332b02.jpg'])
    end

    it "should increase refcount when saving the same image" do
      @multiple.set_image_file :banner1, "#{File.dirname(__FILE__)}/../sample.jpg"
      @multiple.set_image_file :banner2, "#{File.dirname(__FILE__)}/../sample.png"
      @multiple.save!
      expect(MogileImage.find_by_name('bcadded5ee18bfa7c99834f307332b02').refcount).to eq(1)
      @multiple = FactoryGirl.build(:multiple)
      @multiple.set_image_file :banner2, "#{File.dirname(__FILE__)}/../sample.jpg"
      expect{ @multiple.save }.not_to raise_error
      expect(@multiple.banner2).to eq('bcadded5ee18bfa7c99834f307332b02.jpg')
      expect(@mg.list_keys('').shift.sort).to eq(['60de57a8f5cd0a10b296b1f553cb41a9.png', 'bcadded5ee18bfa7c99834f307332b02.jpg'])
      expect(MogileImage.find_by_name('bcadded5ee18bfa7c99834f307332b02').refcount).to eq(2)
      expect(MogileImage.find_by_name('60de57a8f5cd0a10b296b1f553cb41a9').refcount).to eq(1)
    end
  end

  context "deletion" do
    before do
      @multiple1 = FactoryGirl.build(:multiple)
      @multiple1.set_image_file :banner1, "#{File.dirname(__FILE__)}/../sample.jpg"
      @multiple1.set_image_file :banner2, "#{File.dirname(__FILE__)}/../sample.png"
      @multiple1.save!
      @multiple2 = FactoryGirl.build(:multiple)
      @multiple2.set_image_file :banner2, "#{File.dirname(__FILE__)}/../sample.jpg"
      @multiple2.save!
    end

    it "should decrease refcount when deleting duplicated image" do
      expect{ @multiple1.destroy }.not_to raise_error
      expect(@mg.list_keys('').shift.sort).to eq(['bcadded5ee18bfa7c99834f307332b02.jpg',])
      expect(MogileImage.find_by_name('bcadded5ee18bfa7c99834f307332b02').refcount).to eq(1)
      expect(MogileImage.find_by_name('60de57a8f5cd0a10b296b1f553cb41a9')).to be_nil
    end

    it "should delete image data when deleting image" do
      @multiple1.destroy
      expect{ @multiple2.destroy }.not_to raise_error
      expect(@mg.list_keys('')).to be_nil
      expect(MogileImage.find_by_name('bcadded5ee18bfa7c99834f307332b02')).to be_nil
      expect(MogileImage.find_by_name('60de57a8f5cd0a10b296b1f553cb41a9')).to be_nil
    end
  end
end
