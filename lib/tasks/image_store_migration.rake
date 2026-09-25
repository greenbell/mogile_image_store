# coding: utf-8
#
# MogileFS → S3 の移行用(gem v2)。コピー元は mogile_fs.yml の hosts / domain、コピー先は s3 の設定を使う。
# 環境変数で上書きできる:
#   SOURCE_HOSTS=host1:7001,host2:7001  SOURCE_DOMAIN=nightstyle
#   BUCKET=stylenetwork-images  PREFIX=nightstyle/
#   THREADS=8  SKIP_EXISTING=1(既定。0 で上書き)  MAX_MBPS=20(帯域の上限 MB/秒)  LOG_DIR=tmp/image_copy
#
#   rake image_store:copy_all              全キー(途中で止めても LOG_DIR/checkpoint.txt から再開)
#   rake image_store:sync SINCE=2026-09-25 DB に SINCE 以降に入った画像(元画像 + そのリサイズ版)
#   rake image_store:verify [SINCE=...]    DB の元画像が S3 にあるか(無い物は LOG_DIR/missing.txt)
namespace :image_store do
  def image_store_source
    backend = MogileImageStore.backend
    MogileFS::MogileFS.new(domain: ENV['SOURCE_DOMAIN'] || backend['domain'],
                           hosts: ENV['SOURCE_HOSTS']&.split(',') || backend['hosts'],
                           timeout: (ENV['SOURCE_TIMEOUT'] || 30).to_i)
  end

  def image_store_copier
    backend = MogileImageStore.backend
    source = image_store_source
    s3conf = (backend['s3'] || {}).merge({ 'bucket' => ENV['BUCKET'], 'prefix' => ENV['PREFIX'] }.compact)
    dest = MogileImageStore::Storage::S3.new(backend.merge('s3' => s3conf, 'domain' => source.domain))
    puts "コピー元 MogileFS #{source.domain} → コピー先 s3://#{dest.bucket}/#{dest.prefix}"
    MogileImageStore::Copier.new(
      source: source, dest: dest,
      threads: (ENV['THREADS'] || 8).to_i,
      skip_existing: ENV['SKIP_EXISTING'] != '0',
      max_bytes_per_sec: ENV['MAX_MBPS'] && (ENV['MAX_MBPS'].to_f * 1024 * 1024),
      log_dir: ENV['LOG_DIR'] || Rails.root.join('tmp', 'image_copy').to_s,
      klass: backend['class'] || 'image')
  end

  def image_store_scope
    scope = MogileImage.all
    scope = scope.where('created_at >= ?', Time.zone.parse(ENV['SINCE'])) if ENV['SINCE'].present?
    scope
  end

  desc 'MogileFS の全キーを S3 に写す(途中再開可)'
  task copy_all: :environment do
    image_store_copier.copy_all(prefix: ENV['KEY_PREFIX'].to_s)
  end

  desc 'DB に SINCE 以降に入った画像(元画像とリサイズ版)を S3 に写す'
  task sync: :environment do
    copier = image_store_copier
    source = image_store_source
    keys = []
    image_store_scope.in_batches(of: 1000) do |batch|
      batch.pluck(:name).each { |name| source.each_key(name) { |k| keys << k } }
    end
    puts "対象 #{keys.size} キー"
    copier.copy_keys(keys)
  end

  desc 'DB の元画像が S3 にあるか確かめる'
  task verify: :environment do
    keys = []
    image_store_scope.in_batches(of: 1000) do |batch|
      batch.pluck(:name, :image_type).each { |name, type| keys << "#{name}.#{type}" }
    end
    missing = image_store_copier.verify_keys(keys)
    puts "DB の元画像 #{keys.size} 件のうち S3 に無い物 #{missing.size} 件"
  end
end
