import 'dart:io';

/// 全局 HttpOverrides：让 Image.network / NetworkImage 等内部自建的
/// HttpClient 也能按 host 分流走用户配置的 HTTP 代理。
/// 仅对 Bangumi / TMDB 相关域名生效，其余请求保持直连。
class AppHttpOverrides extends HttpOverrides {
  String bangumiProxy = '';
  String tmdbProxy = '';

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)..findProxy = _findProxy;
  }

  String _findProxy(Uri uri) {
    final host = uri.host;
    // api.bgm.tv（接口）与 lain.bgm.tv（图片）均属 bgm.tv
    if (bangumiProxy.isNotEmpty && host.endsWith('bgm.tv')) {
      return 'PROXY $bangumiProxy';
    }
    // api.themoviedb.org（接口）与 image.tmdb.org（图片）
    if (tmdbProxy.isNotEmpty &&
        (host.endsWith('themoviedb.org') || host.endsWith('tmdb.org'))) {
      return 'PROXY $tmdbProxy';
    }
    return 'DIRECT';
  }
}

/// 全局唯一实例：直接修改其字段即可让后续新建的 HttpClient 即时生效，
/// 无需重启 App（每次 new HttpClient 都会重新走 findProxy）。
final AppHttpOverrides appHttpOverrides = AppHttpOverrides();

/// 安装/刷新全局代理 override，幂等可重复调用。
void installHttpProxyOverrides({
  String bangumiProxy = '',
  String tmdbProxy = '',
}) {
  appHttpOverrides.bangumiProxy = bangumiProxy;
  appHttpOverrides.tmdbProxy = tmdbProxy;
  HttpOverrides.global = appHttpOverrides;
}
