# coding: utf-8
require 'spec_helper'

describe MogileImage, type: :routing do
  it{ expect({ get: '/image/raw/0123456789abcdef0123456789abcdef.jpg' }).to route_to(controller: 'mogile_images', action: 'show', size: 'raw', name: '0123456789abcdef0123456789abcdef', format: 'jpg') }
  it{ expect({ get: '/image/1x2/0123456789abcdef0123456789abcdef.gif' }).to route_to(controller: 'mogile_images', action: 'show', size: '1x2', name: '0123456789abcdef0123456789abcdef', format: 'gif') }
  it{ expect({ get: '/image/200x100/0123456789abcdef0123456789abcdef.png' }).to route_to(controller: 'mogile_images', action: 'show', size: '200x100', name: '0123456789abcdef0123456789abcdef', format: 'png') }
  it{ expect({ get: '/image/200x100fill/0123456789abcdef0123456789abcdef.png' }).to route_to(controller: 'mogile_images', action: 'show', size: '200x100fill', name: '0123456789abcdef0123456789abcdef', format: 'png') }
  it{ expect({ get: '/image/200x100fill3/0123456789abcdef0123456789abcdef.png' }).to route_to(controller: 'mogile_images', action: 'show', size: '200x100fill3', name: '0123456789abcdef0123456789abcdef', format: 'png') }
  it{ expect({ get: '/image/raw/0123456789abcdef0123456789abcdef.pdf' }).to route_to(controller: 'mogile_images', action: 'show', size: 'raw', name: '0123456789abcdef0123456789abcdef', format: 'pdf') }
  it{ expect({ post: '/image/flush' }).to route_to(controller: 'mogile_images', action: 'flush') }
  it{ expect({ get: '/image/raw/0123456789abcdef0123456789abcdef' }).not_to be_routable }
  it{ expect({ get: '/image/raw/0123456789abcdef0123456789abcdef' }).not_to be_routable }
  it{ expect({ post: '/image/raw/0123456789abcdef0123456789abcdef.jpg' }).not_to be_routable }
  it{ expect({ put: '/image/raw/0123456789abcdef0123456789abcdef.jpg' }).not_to be_routable }
  it{ expect({ delete: '/image/raw/0123456789abcdef0123456789abcdef.jpg' }).not_to be_routable }
  it{ expect({ get: '/image/flush' }).not_to be_routable }
  it{ expect({ put: '/image/flush' }).not_to be_routable }
  it{ expect({ delete: '/image/flush' }).not_to be_routable }
  it{ expect({ get: '/image/' }).not_to be_routable }

  it{ expect({ get: '/image_tests/2/image_delete/image' }).to route_to(controller: 'image_tests', action: 'image_delete', id: '2', column: 'image') }
  it{ expect({ get: '/multiples/65/image_delete/banner' }).to route_to(controller: 'multiples', action: 'image_delete', id: '65', column: 'banner') }
end
