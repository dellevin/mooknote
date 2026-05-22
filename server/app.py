"""
MookNote 用户统计服务
Flask + SQLite，匿名统计设备数和在线数
"""

import sqlite3
import hashlib
import os
from datetime import datetime, timezone, timedelta

from flask import Flask, request, jsonify

app = Flask(__name__)

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "stats.db")
ONLINE_THRESHOLD_MINUTES = 5  # 超过此时间未心跳视为离线


def get_db() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    with get_db() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS devices (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                device_hash TEXT UNIQUE NOT NULL,
                first_seen TEXT NOT NULL,
                last_seen TEXT NOT NULL
            )
            """
        )
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_last_seen ON devices(last_seen)"
        )
        conn.commit()


# ─── API ────────────────────────────────────────────────────────────────────


@app.route("/api/heartbeat", methods=["POST"])
def heartbeat():
    """接收匿名心跳"""
    data = request.get_json(silent=True) or {}
    device_hash = data.get("device_hash", "").strip()
    if not device_hash:
        return jsonify({"error": "device_hash is required"}), 400

    # 只存哈希，不存原始设备信息
    h = hashlib.sha256(device_hash.encode()).hexdigest()
    now_iso = datetime.now(timezone.utc).isoformat()

    with get_db() as conn:
        row = conn.execute(
            "SELECT id FROM devices WHERE device_hash = ?", (h,)
        ).fetchone()

        if row:
            conn.execute(
                "UPDATE devices SET last_seen = ? WHERE device_hash = ?",
                (now_iso, h),
            )
        else:
            conn.execute(
                "INSERT INTO devices (device_hash, first_seen, last_seen) VALUES (?, ?, ?)",
                (h, now_iso, now_iso),
            )
        conn.commit()

    return jsonify({"status": "ok"})


@app.route("/api/stats", methods=["GET"])
def stats():
    """获取统计：总用户数和当前在线数"""
    threshold = (
        datetime.now(timezone.utc) - timedelta(minutes=ONLINE_THRESHOLD_MINUTES)
    ).isoformat()

    with get_db() as conn:
        total = conn.execute("SELECT COUNT(*) FROM devices").fetchone()[0]
        online = conn.execute(
            "SELECT COUNT(*) FROM devices WHERE last_seen >= ?", (threshold,)
        ).fetchone()[0]

    return jsonify({"total_users": total, "online_users": online})


@app.route("/", methods=["GET"])
def index():
    return "MookNote Stats Server is running."


# ─── MAIN ───────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    init_db()
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=False)
