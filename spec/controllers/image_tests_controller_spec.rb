# coding: utf-8
require 'spec_helper'
require 'net/http'

describe ImageTestsController, type: :controller do
  it "should use ImageTestsController" do
    expect(controller).to be_an_instance_of(ImageTestsController)
  end

  context "With MogileFS Backend", :mogilefs => true do
    before do
      @image_test = FactoryGirl.build(:image_test)
      @image_test.set_image_file :image, "#{File.dirname(__FILE__)}/../sample.jpg"
      @image_test.save
    end

    it "should return status 404 when requested non-existent column" do
      get 'image_delete', :id => @image_test.id, :column => 'picture'
      expect(response.status).to eq(404)
    end

    it "should be deleted" do
      expect(@mg.list_keys('').shift).to eq(['bcadded5ee18bfa7c99834f307332b02.jpg'])
      get 'image_delete', :id => @image_test.id, :column => 'image'
      expect(response.status).to eq(302)
      expect(response.header['Location']).to eq("http://test.host/image_tests/#{@image_test.id}/edit")
      expect(MogileImage.count).to eq(0)
      expect(@mg.list_keys('')).to be_nil
      expect(@image_test.reload[:image]).to be_nil
    end

    it "should show alert on failure" do
      @image_test.image = nil
      @image_test.save!
      get 'image_delete', :id => @image_test.id, :column => 'image'
      expect(response.status).to eq(302)
      expect(response.header['Location']).to eq("http://test.host/image_tests/#{@image_test.id}/edit")
      expect(flash.now[:alert]).to eq('Failed to delete image.')
    end
  end
end

