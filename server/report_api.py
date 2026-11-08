"""崩溃上报 / 意见反馈 公开 API（设备维度，免登录，与心跳同鉴权方式）"""
import hashlib
import re
from datetime import datetime, timezone

from flask import jsonify, request


def _now_iso():
    return datetime.now(timezone.utc).isoformat()


def _hash_device(device_hash: str) -> str:
    return hashlib.sha256(device_hash.encode()).hexdigest()


def _crash_signature(error: str) -> str:
    """崩溃签名：取首行规范化（去数字/地址）后哈希，用于聚合相同崩溃"""
    first = (error.split("\n")[0] if error else "").strip()
    normalized = re.sub(r"0x[0-9a-fA-F]+", "0x", first)
    normalized = re.sub(r"\d+", "N", normalized)
    return hashlib.sha256(normalized.encode()).hexdigest()[:16]


def register_report_routes(app):
    # ─── 崩溃上报 ────────────────────────────────────────────────
    @app.route("/api/crash-report", methods=["POST"])
    def crash_report():
        data = request.get_json(silent=True) or {}
        device_hash = (data.get("device_hash") or "").strip()
        error = (data.get("error") or "").strip()[:8000]
        if not device_hash or not error:
            return jsonify({"error": "device_hash and error are required"}), 400
        h = _hash_device(device_hash)
        from database import get_db
        with get_db() as conn:
            conn.execute(
                "INSERT INTO crash_reports (signature, device_hash, app_version, device_type, error, created_at) "
                "VALUES (?,?,?,?,?,?)",
                (_crash_signature(error), h,
                 (data.get("app_version") or "")[:30],
                 (data.get("device_type") or "")[:20],
                 error, _now_iso()),
            )
            conn.commit()
        return jsonify({"status": "ok"})

    # ─── 意见反馈 ────────────────────────────────────────────────
    @app.route("/api/feedback", methods=["POST"])
    def feedback_submit():
        data = request.get_json(silent=True) or {}
        device_hash = (data.get("device_hash") or "").strip()
        content = (data.get("content") or "").strip()[:2000]
        if not device_hash or not content:
            return jsonify({"error": "device_hash and content are required"}), 400
        h = _hash_device(device_hash)
        from database import get_db
        with get_db() as conn:
            conn.execute(
                "INSERT INTO feedback (device_hash, content, contact, app_version, device_type, status, created_at, updated_at) "
                "VALUES (?,?,?,?,?,'pending',?,?)",
                (h, content,
                 (data.get("contact") or "").strip()[:100],
                 (data.get("app_version") or "")[:30],
                 (data.get("device_type") or "")[:20],
                 _now_iso(), _now_iso()),
            )
            conn.commit()
        return jsonify({"status": "ok"})

    @app.route("/api/feedback", methods=["GET"])
    def feedback_mine():
        """App 端拉取自己的反馈与管理员回复"""
        device_hash = (request.args.get("device_hash") or "").strip()
        if not device_hash:
            return jsonify({"error": "device_hash is required"}), 400
        h = _hash_device(device_hash)
        from database import get_db
        with get_db() as conn:
            rows = conn.execute(
                "SELECT id, content, contact, app_version, status, reply, created_at, updated_at "
                "FROM feedback WHERE device_hash=? ORDER BY created_at DESC LIMIT 50",
                (h,),
            ).fetchall()
        return jsonify({"items": [dict(r) for r in rows]})
