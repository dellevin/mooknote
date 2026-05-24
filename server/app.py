"""MookNote 服务端 - 入口"""
import os
from flask import Flask
from config import JWT_SECRET
from database import init_db
from auth import register_auth_routes
from admin_api import register_admin_routes
from sync_api import register_sync_routes
from data_api import register_data_routes
from web_ui import register_web_routes

app = Flask(__name__)
app.config["SECRET_KEY"] = JWT_SECRET

# 初始化数据库
init_db()

# 注册所有路由模块
register_auth_routes(app)
register_admin_routes(app)
register_sync_routes(app)
register_data_routes(app)
register_web_routes(app)

if __name__ == "__main__":
    from waitress import serve
    port = int(os.environ.get("PORT", 5000))
    print(f"MookNote 服务端启动于 http://0.0.0.0:{port}")
    serve(app, host="0.0.0.0", port=port)
