# coding: utf-8

require 'digest/md5'
require 'json'

module MogileImageStore
  ##
  # MogileFS → S3 のコピー(一括コピー・差分同期・突き合わせ)
  #
  # キーは MogileFS のまま写す(S3 側は "<prefix><key>")。中身は一切変えない。
  # 写した物は、読んだ中身の MD5 と S3 が受け取った中身の MD5(ETag)を比べて、転送で壊れていないかを確かめる。
  # (キーの名前の MD5 はアップロード時点の中身の物で、EXIF の除去や JPEG への変換の後に保存するため、
  #   保存された中身の MD5 とは一致しないのが正常。検証には使わない)
  # 読み出しの失敗は間を置いて 3 回まで試し直す。
  #
  #   copier = Copier.new(source: MogileFS::MogileFS.new(...), dest: Storage::S3.new(...),
  #                       threads: 8, skip_existing: true, log_dir: 'tmp/image_copy')
  #   copier.copy_all                # MogileFS の全キー(途中再開は checkpoint から)
  #   copier.copy_keys(keys)         # 指定したキーだけ(差分同期)
  #   copier.verify_keys(keys)       # S3 にあるかだけ確かめる
  class Copier
    attr_reader :stats

    def initialize(source:, dest:, threads: 8, skip_existing: true, log_dir: 'tmp/image_copy',
                   max_bytes_per_sec: nil, klass: 'image', out: $stdout)
      @source, @dest = source, dest
      @threads = threads.to_i
      @skip_existing = skip_existing
      @log_dir = log_dir
      @max_bps = max_bytes_per_sec&.to_i
      @klass = klass
      @out = out
      @stats = Hash.new(0)
      @lock = Mutex.new
      @started = Time.now
      FileUtils.mkdir_p(@log_dir)
    end

    ##
    # MogileFS の全キーを写す。checkpoint(最後に列挙したキー)を残すので、止めても続きから再開できる
    def copy_all(prefix: '')
      after = File.exist?(checkpoint_path) ? File.read(checkpoint_path).strip.presence : nil
      say "開始: prefix=#{prefix.inspect} 再開位置=#{after.inspect} 並列=#{@threads}"
      run_workers do |queue|
        enumerate(prefix, after) do |key|
          queue << key
          @lock.synchronize { File.write(checkpoint_path, key) if (@stats[:listed] += 1) % 1000 == 0 }
        end
      end
      File.write(checkpoint_path, '') # 最後まで終わったら次は頭から
      report
    end

    def copy_keys(keys)
      run_workers { |queue| keys.each { |k| queue << k } }
      report
    end

    def verify_keys(keys)
      missing = []
      keys.each do |k|
        @stats[:checked] += 1
        missing << k unless @dest.exist?(k)
      end
      File.write(File.join(@log_dir, 'missing.txt'), missing.join("\n")) unless missing.empty?
      @stats[:missing] = missing.size
      report
      missing
    end

    private

    def enumerate(prefix, after)
      # mogilefs-client の list_keys を直接ページ送りする(each_key は再開位置を受けないため)
      loop do
        keys, last = @source.list_keys(prefix, after, 1000)
        break if keys.nil? || keys.empty?
        keys.each { |k| yield k }
        after = last
      end
    end

    def run_workers
      queue = SizedQueue.new(@threads * 50)
      workers = Array.new(@threads) do
        Thread.new do
          while (key = queue.pop) != :done
            copy_one(key)
          end
        end
      end
      yield queue
      @threads.times { queue << :done }
      workers.each(&:join)
    end

    def copy_one(key)
      if @skip_existing && @dest.exist?(key)
        count(:skipped)
        return
      end
      data = read_with_retry(key)
      etag = @dest.store_and_etag(key, data)
      if etag != Digest::MD5.hexdigest(data)
        record('etag_mismatch.txt', "#{key}\t#{etag}")
        count(:etag_mismatch)
      end
      count(:copied, data.bytesize)
      throttle
    rescue ::MogileFS::Backend::UnknownKeyError, ::MogileFS::Error => e
      record('source_errors.txt', "#{key}\t#{e.class}: #{e.message}")
      count(:source_error)
    rescue StandardError => e
      record('dest_errors.txt', "#{key}\t#{e.class}: #{e.message}")
      count(:dest_error)
    end

    def read_with_retry(key, attempts: 3)
      tries = 0
      begin
        tries += 1
        @source.get_file_data(key)
      rescue ::MogileFS::Backend::UnknownKeyError
        raise
      rescue ::MogileFS::Error, IOError, SystemCallError, Timeout::Error
        raise if tries >= attempts
        sleep(2 * tries)
        retry
      end
    end

    def count(name, bytes = 0)
      @lock.synchronize do
        @stats[name] += 1
        @stats[:bytes] += bytes
        done = @stats[:copied] + @stats[:skipped]
        say(progress) if done > 0 && done % 1000 == 0 && name != :skipped || (name == :skipped && @stats[:skipped] % 10_000 == 0)
      end
    end

    def throttle
      return unless @max_bps
      elapsed = Time.now - @started
      wait = @stats[:bytes].to_f / @max_bps - elapsed
      sleep(wait) if wait > 0
    end

    def record(file, line)
      @lock.synchronize { File.open(File.join(@log_dir, file), 'a') { |f| f.puts(line) } }
    end

    def checkpoint_path
      File.join(@log_dir, 'checkpoint.txt')
    end

    def progress
      sec = (Time.now - @started).round
      mb = (@stats[:bytes] / 1024.0 / 1024).round(1)
      "#{Time.now.strftime('%H:%M:%S')} 写した #{@stats[:copied]} 件 #{mb}MB / 既にあった #{@stats[:skipped]} / " \
        "転送で壊れた #{@stats[:etag_mismatch]} / 読み失敗 #{@stats[:source_error]} / 書き失敗 #{@stats[:dest_error]} / #{sec} 秒"
    end

    def report
      say "完了: #{progress}"
      File.write(File.join(@log_dir, "report_#{@started.strftime('%Y%m%d_%H%M%S')}.json"), JSON.pretty_generate(@stats))
      @stats
    end

    def say(msg)
      @out.puts(msg)
      @out.flush if @out.respond_to?(:flush)
    end
  end
end
