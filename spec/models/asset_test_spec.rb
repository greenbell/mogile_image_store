require 'spec_helper'

describe AssetTest, :mogilefs => true do
  let(:mg){ MogileFS::MogileFS.new({ :domain => MogileImageStore.backend['domain'], :hosts  => MogileImageStore.backend['hosts'] }) }

  describe "default validation" do
    subject{ AssetTest.new }
    it "should accept jpeg image" do
      subject.asset = ActionDispatch::Http::UploadedFile.new({
        :filename => 'sample.jpg',
        :tempfile => File.open("#{File.dirname(__FILE__)}/../sample.jpg")
      })
      subject.should be_valid
    end

    it "should accept text file" do
      subject.asset = ActionDispatch::Http::UploadedFile.new({
        :filename => 'sample.txt',
        :tempfile => File.open("#{File.dirname(__FILE__)}/../sample.txt")
      })
      subject.should be_valid
    end
  end

  context "on saving" do
    subject{ AssetTest.new }

    it "should return hash value when saved" do
      subject.set_image_file :asset, "#{File.dirname(__FILE__)}/../sample.txt"
      lambda{ subject.save }.should_not raise_error
      subject.asset.should == 'd2863cc5448b49cfd0ab49dcb0936a89.txt'
      mg.list_keys('').shift.should == ['d2863cc5448b49cfd0ab49dcb0936a89.txt']
    end

    it "should increase refcount when saving the same asset" do
      subject.set_image_file :asset, "#{File.dirname(__FILE__)}/../sample.txt"
      subject.save!
      subject = Factory.build(:asset_test)
      MogileImage.find_by_name('d2863cc5448b49cfd0ab49dcb0936a89').refcount.should == 1
      subject.set_image_file :asset, "#{File.dirname(__FILE__)}/../sample.txt"
      lambda{ subject.save }.should_not raise_error
      subject.asset.should == 'd2863cc5448b49cfd0ab49dcb0936a89.txt'
      mg.list_keys('').shift.should == ['d2863cc5448b49cfd0ab49dcb0936a89.txt']
      MogileImage.find_by_name('d2863cc5448b49cfd0ab49dcb0936a89').refcount.should == 2
    end
  end

  context "on retrieval" do
    subject{ Factory.build(:asset_test) }
    before do
      subject.set_image_file :asset, "#{File.dirname(__FILE__)}/../sample.txt"
      subject.save!
    end

    it "returns raw content of file" do
      content_type, data = MogileImage.fetch_data('d2863cc5448b49cfd0ab49dcb0936a89', 'txt')
      content_type.should == 'text/plain'
      data.should == "This is sample.\n"
    end
  end

  context "on overwriting" do
    subject{ Factory.build(:asset_test) }
    before do
      subject.set_image_file :asset, "#{File.dirname(__FILE__)}/../sample.txt"
      subject.save!
    end

    it "should delete old image when overwritten" do
      subject.set_image_file :asset, "#{File.dirname(__FILE__)}/../sample.gif"
      lambda{ subject.save }.should_not raise_error
      subject.asset.should == '5d1e43dfd47173ae1420f061111e0776.gif'
      mg.list_keys('').shift.sort.should == ['5d1e43dfd47173ae1420f061111e0776.gif']
      MogileImage.find_by_name('d2863cc5448b49cfd0ab49dcb0936a89').should be_nil
      MogileImage.find_by_name('5d1e43dfd47173ae1420f061111e0776').refcount.should == 1
    end
  end
end
