import '../../utils/user_prefs.dart';
import 'cloud_movie_data_service.dart';

/// 云模式图片落地统一入口。
///
/// 云模式：把本地图片上传 OSS，返回 lite 公网 URL（数据库只存网络地址）；
/// 本地模式：原样返回本地路径，调用方按原流程复制/移动文件。
/// [logicalPath] 为 images/ 下相对路径，如 movies/{movieId}/poster_xxx.jpg。
class CloudImageUpload {
  CloudImageUpload._();

  static Future<String> persist({
    required String logicalPath,
    required String localAbsPath,
    bool? cloudMode,
  }) async {
    final useCloud = cloudMode ?? UserPrefs().cloudMovieMode;
    if (!useCloud) return localAbsPath;
    return CloudMovieDataService.instance.uploadImage(logicalPath, localAbsPath);
  }

  /// 已落地的云地址（编辑态旧图片可能本身就是网络 URL）
  static bool isRemoteUrl(String? path) =>
      path != null && path.startsWith('http');
}
