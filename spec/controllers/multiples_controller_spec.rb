# coding: utf-8
require 'spec_helper'
require 'net/http'

describe MultiplesController, type: :controller do
  it "should use MultiplesController" do
    expect(controller).to be_an_instance_of(MultiplesController)
  end

  context "With MogileFS Backend", :mogilefs => true do
    before do
      Factory(:confirm)
      @confirm = Factory(:confirm)
      @multiple = Factory.build(:multiple, :confirm => @confirm)
      @multiple.set_image_file :banner1, "#{File.dirname(__FILE__)}/../sample.jpg"
      @multiple.save
    end

    it "should return status 404 when requested non-existent column" do
      get 'image_delete', :confirm_id => @confirm.id, :id => @multiple.id, :column => 'picture'
      expect(response.status).to eq(404)
    end

    it "should be deleted" do
      expect(@mg.list_keys('').shift).to eq(['bcadded5ee18bfa7c99834f307332b02.jpg'])
      get 'image_delete', :confirm_id => @confirm.id, :id => @multiple.id, :column => 'banner1'
      expect(response.status).to eq(302)
      expect(response.header['Location']).to eq("http://test.host/confirms/2/multiples/#{@multiple.id}/edit")
      expect(MogileImage.count).to eq(0)
      expect(@mg.list_keys('')).to be_nil
      expect(@multiple.reload[:banner1]).to be_nil
    end

    it "should show alert on failure" do
      @multiple.banner1 = nil
      @multiple.save!
      get 'image_delete', :confirm_id => @confirm.id, :id => @multiple.id, :column => 'banner1'
      expect(response.status).to eq(302)
      expect(response.header['Location']).to eq("http://test.host/confirms/2/multiples/#{@multiple.id}/edit")
      expect(flash.now[:alert]).to eq('Failed to delete image.')
    end

    it "image-delete url should be correctly set with nested resource" do
      get 'edit', :confirm_id => @multiple.confirm_id, :id => @multiple.id
      expect(controller.url_for(:action => 'image_delete', :column => 'banner2')).to eq(
        'http://test.host/confirms/2/multiples/1/image_delete?column=banner2'
      )
    end
  end
end

