# coding: utf-8

module MogileImageStore
  module Storage
    ##
    # 移行中に MogileFS と S3 の両方を使う。
    #
    # 書き込み・削除は両方へ。読み出しは read で指定した方を先に見て、無ければもう一方を見る。
    # heal: true なら、もう一方にあった物を先に見る方へ写す(欠けの自己修復)。
    #
    # 「先に見る方」が正(失敗したら例外を上げる)。もう一方への書き込み・削除・修復の失敗は
    # ログに残して握りつぶす(利用者の操作を止めない。欠けは差分同期と自己修復で埋まる)。
    #
    #   移行の段 1〜3: read: mogilefs(今と同じ動き + S3 にも書く)
    #   移行の段 4〜6: read: s3(S3 に無ければ MogileFS から読んで S3 に写す)
    class Mirror
      attr_reader :primary, :secondary

      def initialize(mogilefs:, s3:, read: :mogilefs, heal: true)
        @primary, @secondary = (read.to_sym == :s3 ? [s3, mogilefs] : [mogilefs, s3])
        @heal = heal
      end

      def store_content(key, klass, content)
        result = @primary.store_content(key, klass, content)
        quietly(:store, key) { @secondary.store_content(key, klass, content) }
        result
      end

      def get_file_data(key)
        read(@primary, key)
      rescue ::MogileFS::Backend::UnknownKeyError
        data = read(@secondary, key)
        if @heal
          quietly(:heal, key) { @primary.store_content(key, MogileImageStore.backend['class'], data) }
          log(:info, :healed, key)
        end
        data
      end

      def get_paths(key)
        @primary.get_paths(key)
      end

      def delete(key)
        found = false
        [@primary, @secondary].each do |store|
          begin
            store.delete(key)
            found = true
          rescue ::MogileFS::Backend::UnknownKeyError
          rescue StandardError => e
            raise if store.equal?(@primary)
            log(:warn, :delete, key, e)
          end
        end
        raise ::MogileFS::Backend::UnknownKeyError, "unknown_key #{key}" unless found
        true
      end

      def each_key(prefix, &block)
        seen = {}
        [@primary, @secondary].each do |store|
          begin
            store.each_key(prefix) { |k| block.call(k) unless seen.key?(k); seen[k] = true }
          rescue StandardError => e
            raise if store.equal?(@primary)
            log(:warn, :each_key, prefix, e)
          end
        end
      end

      private

      # MogileFS の台帳にはあるのに、実体が全部の置き場所で 404 の物(ディスクから消えた)は「無い」と同じに扱う。
      # そのままだと MogileFS::Error で 500 になり、リサイズ版なら元画像から作り直されず、
      # 元画像ならもう一方(S3)にあっても読みに行かない。タイムアウトなど 404 以外が混ざるときは例外のまま。
      def read(store, key)
        store.get_file_data(key)
      rescue ::MogileFS::Backend::UnknownKeyError
        raise
      rescue ::MogileFS::Error => e
        raise unless lost_file?(e)
        log(:warn, :lost, key, e)
        raise ::MogileFS::Backend::UnknownKeyError, "unknown_key #{key}"
      end

      # "all paths failed with GET: http://…/x.fid - Not Found (Net::HTTPNotFound), http://…/y.fid - Not Found (Net::HTTPNotFound)"
      def lost_file?(error)
        message = error.message.to_s
        return false unless message.start_with?('all paths failed')
        failures = message.sub(/\Aall paths failed with \w+: /, '').split(/, (?=https?:\/\/)/)
        failures.any? && failures.all? { |f| f.include?('Net::HTTPNotFound') }
      end

      def quietly(action, key)
        yield
      rescue StandardError => e
        log(:warn, action, key, e)
        nil
      end

      def log(level, action, key, error = nil)
        return unless defined?(Rails) && Rails.logger
        Rails.logger.public_send(level, "[mogile_image_store mirror] #{action} #{key}#{error ? " #{error.class}: #{error.message}" : ''}")
      end
    end
  end
end
