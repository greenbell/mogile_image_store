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
      expect(subject).to be_valid
    end

    it "should accept text file" do
      subject.asset = ActionDispatch::Http::UploadedFile.new({
        :filename => 'sample.txt',
        :tempfile => File.open("#{File.dirname(__FILE__)}/../sample.txt")
      })
      expect(subject).to be_valid
    end
  end

  context "on saving" do
    subject{ AssetTest.new }

    it "should return hash value when saved" do
      subject.set_image_file :asset, "#{File.dirname(__FILE__)}/../sample.txt"
      expect{ subject.save }.not_to raise_error
      expect(subject.asset).to eq('d2863cc5448b49cfd0ab49dcb0936a89.txt')
      expect(mg.list_keys('').shift).to eq(['d2863cc5448b49cfd0ab49dcb0936a89.txt'])
    end

    it "should increase refcount when saving the same asset" do
      subject.set_image_file :asset, "#{File.dirname(__FILE__)}/../sample.txt"
      subject.save!
      subject = Factory.build(:asset_test)
      expect(MogileImage.find_by_name('d2863cc5448b49cfd0ab49dcb0936a89').refcount).to eq(1)
      subject.set_image_file :asset, "#{File.dirname(__FILE__)}/../sample.txt"
      expect{ subject.save }.not_to raise_error
      expect(subject.asset).to eq('d2863cc5448b49cfd0ab49dcb0936a89.txt')
      expect(mg.list_keys('').shift).to eq(['d2863cc5448b49cfd0ab49dcb0936a89.txt'])
      expect(MogileImage.find_by_name('d2863cc5448b49cfd0ab49dcb0936a89').refcount).to eq(2)
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
      expect(content_type).to eq('text/plain')
      expect(data).to eq("This is sample.\n")
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
      expect{ subject.save }.not_to raise_error
      expect(subject.asset).to eq('5d1e43dfd47173ae1420f061111e0776.gif')
      expect(mg.list_keys('').shift.sort).to eq(['5d1e43dfd47173ae1420f061111e0776.gif'])
      expect(MogileImage.find_by_name('d2863cc5448b49cfd0ab49dcb0936a89')).to be_nil
      expect(MogileImage.find_by_name('5d1e43dfd47173ae1420f061111e0776').refcount).to eq(1)
    end
  end
end
