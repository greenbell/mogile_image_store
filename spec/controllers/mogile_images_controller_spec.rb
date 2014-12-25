# coding: utf-8
require 'spec_helper'
require 'net/http'

describe MogileImagesController, type: :controller do
  it "should use MogileImagesController" do
    expect(controller).to be_an_instance_of(MogileImagesController)
  end

  context "With MogileFS Backend" do
    before(:all) do
      #prepare mogilefs
      @mogadm = MogileFS::Admin.new hosts: MogileImageStore.backend['hosts']
      unless @mogadm.get_domains[MogileImageStore.backend['domain']]
        @mogadm.create_domain MogileImageStore.backend['domain']
        @mogadm.create_class  MogileImageStore.backend['domain'], MogileImageStore.backend['class'], 2 rescue nil
      end
      @mg = MogileFS::MogileFS.new({ domain: MogileImageStore.backend['domain'], hosts: MogileImageStore.backend['hosts'] })
      image_test = FactoryGirl.build(:image_test)
      image_test.set_image_file :image, "#{File.dirname(__FILE__)}/../sample.jpg"
      image_test.save
      asset_test = FactoryGirl.build(:asset_test)
      asset_test.set_image_file :asset, "#{File.dirname(__FILE__)}/../sample.txt"
      asset_test.save
    end
    before do
      @mg = MogileFS::MogileFS.new({ domain: MogileImageStore.backend['domain'], hosts: MogileImageStore.backend['hosts'] })
    end
    after(:all) do
      #cleanup
      MogileImage.destroy_all
      @mogadm = MogileFS::Admin.new hosts: MogileImageStore.backend['hosts']
      @mg = MogileFS::MogileFS.new({ domain: MogileImageStore.backend['domain'], hosts: MogileImageStore.backend['hosts'] })
      @mg.each_key('') {|k| @mg.delete k }
      @mogadm.delete_domain MogileImageStore.backend['domain']
    end

    it "should return raw jpeg image" do
      get 'show', name: 'bcadded5ee18bfa7c99834f307332b02', format: 'jpg', size: 'raw'
      expect(response).to be_success
      expect(response.header['Content-Type']).to eq('image/jpeg')
      img = ::Magick::Image.from_blob(response.body).shift
      expect(img.format).to eq('JPEG')
      expect(img.columns).to eq(725)
      expect(img.rows).to eq(544)
    end

    it "should return raw text file" do
      get 'show', name: 'd2863cc5448b49cfd0ab49dcb0936a89', format: 'txt', size: 'raw'
      expect(response).to be_success
      expect(response.header['Content-Type']).to eq('text/plain')
      expect(response.body).to eq("This is sample.\n")
    end

    it "should return status 404 when requested non-existent image" do
      get 'show', name: 'bcadded5ee18bfa7c99834f307332b01', format: 'jpg', size: 'raw'
      expect(response.status).to eq(404)
    end

    it "should respond 206 if reproxying is disabled" do
      post 'flush'
      expect(response.status).to eq(206)
    end

    context "Reproxing" do
      before(:all) do
        MogileImageStore.backend['reproxy'] = true
        MogileImageStore.backend['cache']   = 7.days
      end
      after (:all){ MogileImageStore.backend['reproxy'] = false }

      it "should return url for jpeg image" do
        get 'show', name: 'bcadded5ee18bfa7c99834f307332b02', format: 'jpg', size: 'raw'
        expect(response).to be_success
        expect(response.header['Content-Type']).to eq('image/jpeg')
        expect(response.header['X-REPROXY-CACHE-FOR']).to eq('604800; Content-Type')
        urls = response.header['X-REPROXY-URL'].split(' ')
        url = URI.parse(urls.shift)
        img = ::Magick::Image.from_blob(Net::HTTP.get(url.host, url.path, url.port)).shift
        expect(img.format).to eq('JPEG')
        expect(img.columns).to eq(725)
        expect(img.rows).to eq(544)
      end

      it "should respond 401 with authorization failure" do
        request.env[MogileImageStore::AUTH_HEADER_ENV] = 'abc'
        request.env['RAW_POST_DATA'] = '/image/raw/bcadded5ee18bfa7c99834f307332b02.jpg'
        post 'flush'
        expect(response.status).to eq(401)
      end

      it "should respond reproxy cache clear header" do
        request.env[MogileImageStore::AUTH_HEADER_ENV] = MogileImageStore.auth_key('/image/raw/bcadded5ee18bfa7c99834f307332b02.jpg')
        request.env['RAW_POST_DATA'] = '/image/raw/bcadded5ee18bfa7c99834f307332b02.jpg'
        post 'flush'
        expect(response).to be_success
        expect(response.header['X-REPROXY-CACHE-CLEAR']).to eq('/image/raw/bcadded5ee18bfa7c99834f307332b02.jpg')
      end
    end
  end
end

