# coding: utf-8
require 'spec_helper'

describe MogileImageStore::TagHelper, type: :helper do
  it "should show image tag" do
    expect(image('0123456789abcdef0123456789abcdef.jpg')).to be_equivalent_to '<img src="'+MogileImageStore.backend['base_url']+'raw/0123456789abcdef0123456789abcdef.jpg" />'
  end

  it "should show image tag with size" do
    expect(image('0123456789abcdef0123456789abcdef.jpg', :w => 80, :h => 80)).to be_equivalent_to '<img src="'+MogileImageStore.backend['base_url']+'80x80/0123456789abcdef0123456789abcdef.jpg" />'
  end

  it "should show image tag with string-keyed size" do
    expect(image('0123456789abcdef0123456789abcdef.jpg', 'w' => 80, 'h' => 80)).to be_equivalent_to '<img src="'+MogileImageStore.backend['base_url']+'80x80/0123456789abcdef0123456789abcdef.jpg" />'
  end

  it "should show image tag with size and format" do
    expect(image('0123456789abcdef0123456789abcdef.jpg', :w => 80, :h => 80, :format => :png)).to be_equivalent_to '<img src="'+MogileImageStore.backend['base_url']+'80x80/0123456789abcdef0123456789abcdef.png" />'
  end

  it "should show image tag with size and alt" do
    expect(image('0123456789abcdef0123456789abcdef.jpg', :w => 80, :h => 80, :alt => 'alt text')).to be_equivalent_to '<img alt="alt text" src="'+MogileImageStore.backend['base_url']+'80x80/0123456789abcdef0123456789abcdef.jpg" />'
  end

  it "should show image tag with size and method" do
    expect(image('0123456789abcdef0123456789abcdef.jpg', :w => 80, :h => 80, :method => :fill3)).to be_equivalent_to '<img src="'+MogileImageStore.backend['base_url']+'80x80fill3/0123456789abcdef0123456789abcdef.jpg" />'
  end

  it "should show image tag with combined size" do
    expect(image('0123456789abcdef0123456789abcdef.jpg', :size => '80x80fill5')).to be_equivalent_to '<img src="'+MogileImageStore.backend['base_url']+'80x80fill5/0123456789abcdef0123456789abcdef.jpg" />'
  end

  it "should alternative image without key" do
    expect(image('')).to be_equivalent_to '<img src="'+MogileImageStore.backend['base_url']+'raw/44bd273c0eddca6de148fd717db8653e.jpg" />'
  end

  it "should specified alternative image without key" do
    expect(image('', :default => :another)).to be_equivalent_to '<img src="'+MogileImageStore.backend['base_url']+'raw/ffffffffffffffffffffffffffffffff.jpg" />'
  end

  context "thumbnail" do
    it "should show thumbnail with link to fullsize image" do
      expect(thumbnail('0123456789abcdef0123456789abcdef.jpg')).to be_equivalent_to '<a href="'+MogileImageStore.backend['base_url']+'raw/0123456789abcdef0123456789abcdef.jpg" target="_blank"><img src="'+MogileImageStore.backend['base_url']+'80x80/0123456789abcdef0123456789abcdef.jpg" /></a>'
    end

    it "should show thumbnail without link" do
      expect(thumbnail('0123456789abcdef0123456789abcdef.jpg', :link => false)).to be_equivalent_to '<img src="'+MogileImageStore.backend['base_url']+'80x80/0123456789abcdef0123456789abcdef.jpg" />'
    end

    it "should show sized thumbnail with link to fullsize image" do
      expect(thumbnail('0123456789abcdef0123456789abcdef.jpg', :w => 60, :h => 90)).to be_equivalent_to '<a href="'+MogileImageStore.backend['base_url']+'raw/0123456789abcdef0123456789abcdef.jpg" target="_blank"><img src="'+MogileImageStore.backend['base_url']+'60x90/0123456789abcdef0123456789abcdef.jpg" /></a>'
    end

    it "should not show link with empty key" do
      expect(thumbnail(nil)).to be_equivalent_to '<img src="'+MogileImageStore.backend['base_url']+'80x80/44bd273c0eddca6de148fd717db8653e.jpg" />'
      expect(thumbnail('')).to be_equivalent_to '<img src="'+MogileImageStore.backend['base_url']+'80x80/44bd273c0eddca6de148fd717db8653e.jpg" />'
    end
  end
end
