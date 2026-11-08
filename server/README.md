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
