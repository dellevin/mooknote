"""MookNote 服务端 - 入口"""
import os
from flask import Flask, request
from config import JWT_SECRET
from database import init_db
from auth import register_auth_routes
from admin_api import register_admin_routes
from sync_api import register_sync_routes
from web_ui import register_web_routes
from export_api import register_export_routes
from report_api import register_report_routes
from backup import start_backup_thread

app = Flask(__name__)
app.config["SECRET_KEY"] = JWT_SECRET

# CORS：允许管理后台跨域调用（环境变量 CORS_ALLOW_ORIGINS 可覆盖，逗号分隔多个来源）
CORS_ALLOW_ORIGINS = {
    o.strip()
    for o in os.environ.get(
        "CORS_ALLOW_ORIGINS", "https://vipapi.mooknote.iletter.top"
    ).split(",")
    if o.strip()
}


@app.after_request
def add_cors_headers(resp):
    origin = request.headers.get("Origin", "")
    if origin in CORS_ALLOW_ORIGINS:
        resp.headers["Access-Control-Allow-Origin"] = origin
        resp.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
        resp.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
        resp.headers["Access-Control-Max-Age"] = "86400"
    return resp

# 初始化数据库
init_db()

# 注册所有路由模块
register_auth_routes(app)
register_admin_routes(app)
register_sync_routes(app)
register_web_routes(app)
register_export_routes(app)
register_report_routes(app)
start_backup_thread()

if __name__ == "__main__":
    from waitress import serve
    port = int(os.environ.get("PORT", 27047))
    print(f"MookNote 服务端启动于 http://127.0.0.1:{port}")
    serve(app, host="0.0.0.0", port=port)
