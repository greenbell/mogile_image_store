// CloudFront Functions(cloudfront-js-2.0、ビューアーリクエスト)
// URL の /image/<size>/<md5>.<format> を、S3 のキー(= MogileFS のキー)の形に書き換える。
//   /image/raw/<md5>.<ext>        → /<md5>.<ext>
//   /image/300x300/<md5>.webp     → /<md5>.webp/300x300
// S3 の元は「元のパス」に /<domain>(例 /nightstyle)、Rails の元は /_image_origin を付けて使う。
// 形の合わない URL(旧 WebP の /image/<id>/small_*.webp など)は書き換えない(S3 に無い → Rails → 404)。
function handler(event) {
  var request = event.request;
  var m = request.uri.match(/^\/image\/(raw|\d+x\d+[a-z]*\d*)\/([0-9a-f]{32}\.[A-Za-z0-9]+)$/);
  if (m) {
    request.uri = (m[1] === 'raw') ? '/' + m[2] : '/' + m[2] + '/' + m[1];
  }
  return request;
}
