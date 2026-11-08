"""同步 API"""
import threading
import time
from datetime import datetime, timezone, timedelta
from flask import jsonify

from config import CRASH_RETENTION_DAYS, FEEDBACK_DONE_RETENTION_DAYS


def _cleanup_old_logs():
    """删除超期崩溃上报/已处理反馈，防止表无限增长"""
    from database import get_db
    now = datetime.now(timezone.utc)
    crash_cutoff = (now - timedelta(days=CRASH_RETENTION_DAYS)).isoformat()
    fb_cutoff = (now - timedelta(days=FEEDBACK_DONE_RETENTION_DAYS)).isoformat()
    with get_db() as conn:
        conn.execute("DELETE FROM crash_reports WHERE created_at < ?", (crash_cutoff,))
        conn.execute("DELETE FROM feedback WHERE status='done' AND updated_at < ?", (fb_cutoff,))
        conn.commit()


def _cleaner_loop():
    while True:
        try:
            _cleanup_old_logs()
        except Exception:
            pass
        time.sleep(86400)


def register_sync_routes(app):
    threading.Thread(target=_cleaner_loop, daemon=True).start()

    # ─── 增强视频校验值 ──────────────────────────────────────────
    @app.route("/api/enhance-video", methods=["GET"])
    def enhance_video():
        from database import get_db
        with get_db() as conn:
            row = conn.execute(
                "SELECT value FROM kv_settings WHERE key=?", ("enhance_video_value",)
            ).fetchone()
        value = row["value"] if row else ""
        return jsonify({"code": 0, "data": value})
