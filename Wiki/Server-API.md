# 服务端 API

## 概述

服务端为 Python Flask 应用，位于 `server/` 目录。提供用户统计、数据同步和管理后台功能。

## 模块结构

| 文件 | 职责 |
|------|------|
| `app.py` | 入口，注册所有路由模块 |
| `config.py` | 配置（JWT 密钥、数据库路径、备份目录）|
| `database.py` | 数据库初始化与管理（SQLite）|
| `auth.py` | 认证路由（激活码验证）|
| `admin_api.py` | 管理后台 API |
| `sync_api.py` | 同步 API（文件上传/下载、心跳）|
| `data_api.py` | 数据 CRUD API（影视/书籍/笔记/标签/图片）|
| `web_ui.py` | Web 管理界面 |
| `static/` | 静态资源 |
| `requirements.txt` | Python 依赖 |

## API 端点

### 认证

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/activate` | 校验激活码 |

请求体：`{"code": "激活码", "device_id": "设备标识"}`

响应：`{"valid": true, "expires_at": "...", "is_permanent": false}`

### 数据 CRUD

所有请求需在 body 中附带 `code` 字段。

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/data/movies` | 获取影视列表（支持 status/limit/offset）|
| POST | `/api/data/movie/save` | 保存影视（新建/更新）|
| POST | `/api/data/movie/delete` | 删除影视 |
| POST | `/api/data/books` | 获取书籍列表 |
| POST | `/api/data/book/save` | 保存书籍 |
| POST | `/api/data/book/delete` | 删除书籍 |
| POST | `/api/data/notes` | 获取笔记列表 |
| POST | `/api/data/note/save` | 保存笔记 |
| POST | `/api/data/note/delete` | 删除笔记 |
| POST | `/api/data/movie_reviews` | 获取影评 |
| POST | `/api/data/movie_review/save` | 保存影评 |
| POST | `/api/data/movie_review/delete` | 删除影评 |
| POST | `/api/data/movie_posters` | 获取海报 |
| POST | `/api/data/movie_poster/save` | 保存海报 |
| POST | `/api/data/movie_poster/delete` | 删除海报 |
| POST | `/api/data/book_reviews` | 获取书评 |
| POST | `/api/data/book_review/save` | 保存书评 |
| POST | `/api/data/book_review/delete` | 删除书评 |
| POST | `/api/data/book_excerpts` | 获取摘抄 |
| POST | `/api/data/book_excerpt/save` | 保存摘抄 |
| POST | `/api/data/book_excerpt/delete` | 删除摘抄 |
| POST | `/api/data/tags` | 获取标签 |
| POST | `/api/data/tag/save` | 保存标签 |
| POST | `/api/data/tag/delete` | 删除标签 |

### 同步

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/heartbeat` | 设备心跳上报 |
| POST | `/api/sync/upload` | 上传数据库/图片文件 |
| POST | `/api/sync/download` | 下载数据库/图片文件 |

### 图片

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/data/image/upload` | 上传图片 |
| GET | `/api/data/image/{code}/{path}` | 获取图片 |

## 激活码机制

每个激活码对应一个独立的 SQLite 数据库：

```
server/backups/{CODE}/
├── database/
│   └── mooknote.db     ← 该激活码的数据
├── images/              ← 图片文件
└── avatars/             ← 头像文件
```

激活码校验通过 `admin_api.py` 中的 `_verify_code()` 函数完成，支持有效期和永久有效两种模式。

## 服务端数据库

服务端自身使用 `stats.db` 存储设备信息和心跳日志：

| 表 | 说明 |
|----|------|
| `devices` | 设备注册（device_hash, first_seen, last_seen）|
| `heartbeat_logs` | 心跳日志（device_hash, ip, device_type, device_name）|
| `changelog` | 更新日志 |

每个激活码的数据存储在独立的 `backups/{code}/database/mooknote.db` 中，表结构与客户端一致。

## 启动

```bash
cd server
python app.py          # 开发环境（waitress）
# 或
gunicorn -w 2 -b 0.0.0.0:27047 app:app  # 生产环境
```

默认端口：27047（可通过环境变量 `PORT` 修改）。

[返回首页](Home.md)
