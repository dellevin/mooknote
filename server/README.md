# MookNote 用户统计服务

## 部署

### 1. 安装依赖

```bash
cd server
pip install -r requirements.txt
```

### 2. 启动服务

```bash
python app.py
```

默认监听 `0.0.0.0:5000`，可通过环境变量 `PORT` 修改端口。

### 3. 生产环境部署

推荐使用 gunicorn：

```bash
pip install gunicorn
gunicorn -w 2 -b 0.0.0.0:5000 app:app
```

或使用 systemd 设为开机自启。

## API

### POST /api/heartbeat
心跳上报，App 启动时和每 5 分钟调用一次。

请求体：
```json
{ "device_hash": "设备匿名标识" }
```

### GET /api/stats
获取统计数据。

响应：
```json
{ "total_users": 10, "online_users": 3 }
```

- `total_users`: 历史总设备数
- `online_users`: 最近 5 分钟内有心跳的设备数

## 数据存储

SQLite 数据库 `stats.db`，结构：

```sql
CREATE TABLE devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_hash TEXT UNIQUE NOT NULL,  -- SHA256 哈希后的设备标识
    first_seen TEXT NOT NULL,           -- 首次出现时间
    last_seen TEXT NOT NULL             -- 最后心跳时间
);
```

所有数据均为匿名，不包含任何设备原始信息。
