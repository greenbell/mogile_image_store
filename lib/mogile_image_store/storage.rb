# coding: utf-8

module MogileImageStore
  ##
  # 画像の保存先(v2)
  #
  # gem の中のロジック(キーの組み立て・拡張子の判定・リサイズ・削除時の一覧)は v1 のまま触らず、
  # MogileImage.mogilefs_connection が返す「保存先」だけを差し替える。
  # 保存先はどれも MogileFS::MogileFS と同じ 5 つのメソッドを持つ:
  #
  #   store_content(key, klass, content)  保存
  #   get_file_data(key)                  読み出し(無ければ MogileFS::Backend::UnknownKeyError)
  #   get_paths(key)                      reproxy 用の URL 一覧(S3 では使わない)
  #   delete(key)                         削除(無ければ MogileFS::Backend::UnknownKeyError)
  #   each_key(prefix) { |key| }          prefix で始まるキーを列挙
  #
  # mogile_fs.yml の storage で選ぶ(書かなければ v1 と同じ mogilefs):
  #
  #   storage: mogilefs | s3 | mirror
  #   s3:
  #     bucket: stylenetwork-images
  #     region: ap-northeast-1
  #     prefix: nightstyle/          # 省略時は "#{domain}/"
  #     fallback_bucket: ...         # 読み出しだけの予備(ローカル開発で本番の画像を見る用)
  #     fallback_prefix: nightstyle/
  #   mirror:                        # storage: mirror のとき
  #     read: s3                     # 先に読む方(s3 | mogilefs)
  #     heal: true                   # 先に読む方に無く、もう一方にあったら写す
  #
  module Storage
    autoload :S3,     'mogile_image_store/storage/s3'
    autoload :Mirror, 'mogile_image_store/storage/mirror'

    def self.build(backend = MogileImageStore.backend)
      case (backend['storage'] || 'mogilefs').to_s
      when 'mogilefs' then mogilefs(backend)
      when 's3'       then S3.new(backend)
      when 'mirror'
        mirror = backend['mirror'] || {}
        Mirror.new(mogilefs: mogilefs(backend), s3: S3.new(backend),
                   read: (mirror['read'] || 'mogilefs').to_sym, heal: mirror.fetch('heal', true))
      else
        raise ArgumentError, "unknown storage: #{backend['storage']}"
      end
    end

    def self.mogilefs(backend)
      ::MogileFS::MogileFS.new(domain: backend['domain'], hosts: backend['hosts'],
                               timeout: backend['timeout'] || 3)
    end
  end
end
