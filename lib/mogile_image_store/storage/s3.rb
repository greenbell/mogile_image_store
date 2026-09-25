# coding: utf-8

require 'aws-sdk-s3'

module MogileImageStore
  module Storage
    ##
    # S3 に保存する。キーは MogileFS のキーをそのまま使い、前に "<domain>/" を付ける。
    #   "abc….jpg"          → "nightstyle/abc….jpg"          (元画像・添付)
    #   "abc….webp/300x300" → "nightstyle/abc….webp/300x300" (リサイズ版)
    # こうしておくと、gem のキーの組み立て・拡張子の判定・削除時の前方一致の一覧が v1 のまま動く。
    #
    # fallback_bucket を指定すると、読み出しで見つからなかったときにそちらも見る(読むだけ)。
    # ローカル開発で、自分の書き込みは開発用バケットへ、本番の画像は本番バケットから読むために使う。
    # 削除と書き込みは fallback に絶対に行かない。
    class S3
      NOT_FOUND = [Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NotFound].freeze

      attr_reader :bucket, :prefix, :fallback_bucket, :fallback_prefix

      def initialize(backend)
        conf = backend['s3'] || {}
        @bucket = conf['bucket'] or raise ArgumentError, 'mogile_fs.yml の s3.bucket がありません'
        @prefix = conf['prefix'] || "#{backend['domain']}/"
        @fallback_bucket = conf['fallback_bucket']
        @fallback_prefix = conf['fallback_prefix'] || @prefix
        @cache_control = conf['cache_control'] || 'public, max-age=31536000, immutable'
        options = { region: conf['region'] || 'ap-northeast-1',
                    http_open_timeout: (conf['open_timeout'] || 3).to_f,
                    http_read_timeout: (conf['read_timeout'] || 20).to_f,
                    retry_limit: (conf['retry_limit'] || 3).to_i }
        if conf['access_key_id'].present?
          options[:credentials] = Aws::Credentials.new(conf['access_key_id'], conf['secret_access_key'])
        end
        options[:endpoint] = conf['endpoint'] if conf['endpoint'].present?          # MinIO などで試すとき
        options[:force_path_style] = true if conf['force_path_style']
        @client = Aws::S3::Client.new(options)
      end

      def store_content(key, _klass, content)
        store_and_etag(key, content)
        content.to_s.bytesize
      end

      # 保存して S3 の ETag(1 回で送った物は中身の MD5)を返す。コピーの検証用
      def store_and_etag(key, content)
        resp = @client.put_object(bucket: @bucket, key: object_key(key), body: content.to_s,
                                  content_type: content_type_for(key), cache_control: @cache_control)
        resp.etag.to_s.delete('"')
      end

      # MogileFS と同じく BINARY の文字列で返す(aws-sdk は US-ASCII の札で返すことがある)
      def get_file_data(key)
        @client.get_object(bucket: @bucket, key: object_key(key)).body.read.force_encoding(Encoding::BINARY)
      rescue *NOT_FOUND
        read_fallback(key)
      end

      # reproxy(Perlbal)用。S3 では使わない(storage: s3 のときは reproxy: false にする)
      def get_paths(key)
        exist?(key) ? ["s3://#{@bucket}/#{object_key(key)}"] : raise(unknown_key(key))
      end

      def delete(key)
        @client.delete_object(bucket: @bucket, key: object_key(key))
        true
      end

      def each_key(key_prefix)
        token = nil
        loop do
          resp = @client.list_objects_v2(bucket: @bucket, prefix: object_key(key_prefix), continuation_token: token)
          resp.contents.each { |o| yield o.key.delete_prefix(@prefix) }
          break unless resp.is_truncated
          token = resp.next_continuation_token
        end
      end

      def exist?(key)
        @client.head_object(bucket: @bucket, key: object_key(key))
        true
      rescue *NOT_FOUND
        false
      end

      def object_key(key)
        "#{@prefix}#{key}"
      end

      # "abc.jpg" → image/jpeg、"abc.webp/300x300" → image/webp、"abc.js" → application/javascript
      def content_type_for(key)
        ext = key.to_s[/\.([A-Za-z0-9]+)(?:\/|\z)/, 1]
        (ext && MIME::Types.type_for(ext).first&.content_type) || 'application/octet-stream'
      end

      private

      def read_fallback(key)
        raise unknown_key(key) unless @fallback_bucket
        @client.get_object(bucket: @fallback_bucket, key: "#{@fallback_prefix}#{key}").body.read.force_encoding(Encoding::BINARY)
      rescue *NOT_FOUND, Aws::S3::Errors::AccessDenied
        raise unknown_key(key)
      end

      def unknown_key(key)
        ::MogileFS::Backend::UnknownKeyError.new("unknown_key #{key}")
      end
    end
  end
end
