# 图片存储

## ImagePathHelper

`lib/utils/image_path_helper.dart` — 单例图片路径管理器。

```dart
class ImagePathHelper {
  static final ImagePathHelper instance = ImagePathHelper._init();
}
```

## 存储目录结构

图片存储在应用文档目录下：

```
{appDocumentsDir}/images/
├── movies/
│   └── {movieId}/
│       ├── poster.jpg              ← 影视海报
│       └── posterimgs/             ← 海报墙图片
│           ├── img1.jpg
│           └── img2.jpg
├── books/
│   └── {bookId}/
│       └── cover.jpg               ← 书籍封面
└── notes/
    └── {noteId}/
        ├── img1.jpg                ← 笔记图片
        └── img2.jpg
```

## 路径方法

### 影视

```dart
getMovieImagesDir(movieId)          → images/movies/{movieId}/
getMoviePosterPath(movieId, file)   → images/movies/{movieId}/{file}
getMoviePosterImgsDir(movieId)      → images/movies/{movieId}/posterimgs/
getMoviePosterImgPath(movieId, file)→ images/movies/{movieId}/posterimgs/{file}
```

### 书籍

```dart
getBookImagesDir(bookId)            → images/books/{bookId}/
getBookCoverPath(bookId, file)      → images/books/{bookId}/{file}
```

### 笔记

```dart
getNoteImagesDir(noteId)            → images/notes/{noteId}/
getNoteImagePath(noteId, file)      → images/notes/{noteId}/{file}
```

## 文件操作

```dart
ensureDirExists(dirPath)     // 确保目录存在
moveFile(src, targetDir, fileName)  // 移动文件
copyFile(src, targetDir, fileName)  // 复制文件
deleteFile(filePath)                // 删除单个文件
deleteMovieImages(movieId)          // 删除影视所有图片目录
deleteBookImages(bookId)            // 删除书籍所有图片目录
deleteNoteImages(noteId)            // 删除笔记所有图片目录
```

## 远程图片同步

当 `_useRemote == true` 时，CRUD 操作会自动调用 `ServerDataService.uploadLocalImages(paths)` 上传本地图片到服务端：

```dart
// AppProvider 中
await _uploadImagesIfRemote([movie.posterPath]);
```

## 图片显示

`FadeInLocalImage` Widget（`lib/widgets/fade_in_local_image.dart`）处理本地图片的渐入显示。

[返回首页](Home.md)
