"""认证模块 - JWT 令牌 + 登录"""
import hashlib
import jwt
import threading
from datetime import datetime, timezone, timedelta
from functools import wraps
from flask import request, jsonify, g
from config import JWT_SECRET, JWT_EXPIRE_HOURS
from database import get_db


# 登录失败计数与临时锁定（内存态，重启清零）
# 失败 ≥5 次锁 10 分钟，≥10 次锁 1 天；登录成功清零
_login_fails = {}
_login_fails_lock = threading.Lock()


def _locked_remaining(username: str):
    """返回剩余锁定秒数，未锁定返回 None"""
    with _login_fails_lock:
        rec = _login_fails.get(username)
        if not rec or not rec["lock_until"]:
            return None
        remain = (rec["lock_until"] - datetime.now(timezone.utc)).total_seconds()
        if remain <= 0:
            rec["lock_until"] = None
            return None
        return remain


def _record_login_fail(username: str):
    with _login_fails_lock:
        rec = _login_fails.setdefault(username, {"count": 0, "lock_until": None})
        rec["count"] += 1
        now = datetime.now(timezone.utc)
        if rec["count"] >= 10:
            rec["lock_until"] = now + timedelta(days=1)
        elif rec["count"] >= 5:
            rec["lock_until"] = now + timedelta(minutes=10)


def _reset_login_fails(username: str):
    with _login_fails_lock:
        _login_fails.pop(username, None)


def make_token(user_id: int, username: str) -> str:
    payload = {
        "user_id": user_id,
        "username": username,
        "exp": datetime.now(timezone.utc) + timedelta(hours=JWT_EXPIRE_HOURS),
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")


def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return jsonify({"error": "未提供认证令牌"}), 401
        token = auth_header[7:]
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
            g.current_user_id = payload["user_id"]
            g.current_username = payload["username"]
        except jwt.ExpiredSignatureError:
            return jsonify({"error": "令牌已过期，请重新登录"}), 401
        except jwt.InvalidTokenError:
            return jsonify({"error": "无效的令牌"}), 401
        return f(*args, **kwargs)
    return decorated


def register_auth_routes(app):
    @app.route("/api/auth/login", methods=["POST"])
    def login():
        data = request.get_json(silent=True) or {}
        username = data.get("username", "").strip()
        password = data.get("password", "").strip()
        if not username or not password:
            return jsonify({"error": "请输入用户名和密码"}), 400
        remain = _locked_remaining(username)
        if remain is not None:
            if remain >= 3600:
                msg = f"失败次数过多，账号已锁定，请 {int(remain // 3600)} 小时后再试"
            else:
                msg = f"失败次数过多，账号已锁定，请 {int(remain // 60) + 1} 分钟后再试"
            return jsonify({"error": msg}), 429
        password_hash = hashlib.sha256(password.encode()).hexdigest()
        with get_db() as conn:
            user = conn.execute(
                "SELECT id, username FROM admin_users WHERE username = ? AND password_hash = ?",
                (username, password_hash),
            ).fetchone()
        if not user:
            _record_login_fail(username)
            return jsonify({"error": "用户名或密码错误"}), 401
        _reset_login_fails(username)
        token = make_token(user["id"], user["username"])
        return jsonify({"token": token, "username": user["username"]})

    @app.route("/api/auth/me", methods=["GET"])
    @login_required
    def me():
        return jsonify({"user_id": g.current_user_id, "username": g.current_username})

    @app.route("/api/auth/change-password", methods=["POST"])
    @login_required
    def change_password():
        data = request.get_json(silent=True) or {}
        old_pw = (data.get("old_password") or "").strip()
        new_pw = (data.get("new_password") or "").strip()
        if not old_pw or not new_pw:
            return jsonify({"error": "请输入旧密码和新密码"}), 400
        if len(new_pw) < 6:
            return jsonify({"error": "新密码至少6个字符"}), 400
        old_hash = hashlib.sha256(old_pw.encode()).hexdigest()
        with get_db() as conn:
            user = conn.execute(
                "SELECT id FROM admin_users WHERE id=? AND password_hash=?",
                (g.current_user_id, old_hash),
            ).fetchone()
            if not user:
                return jsonify({"error": "旧密码错误"}), 403
            new_hash = hashlib.sha256(new_pw.encode()).hexdigest()
            conn.execute("UPDATE admin_users SET password_hash=? WHERE id=?", (new_hash, g.current_user_id))
            conn.commit()
        return jsonify({"status": "ok"})
