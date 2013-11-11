# coding: utf-8
require 'spec_helper'

describe MogileImage do
  it "should return image url" do
    MogileImage.image_url('60de57a8f5cd0a10b296b1f553cb41a9.png').should ==
      'http://image.example.com/image/raw/60de57a8f5cd0a10b296b1f553cb41a9.png'
  end

  describe "#mime_type_for" do
    it "does not break when symbol is given" do
      MogileImage.mime_type_for(:jpg).should == ['image/jpeg']
    end
  end
end

