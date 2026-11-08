"""管理后台 API"""
import json
from datetime import datetime, timezone
from flask import request, jsonify
from auth import login_required
from database import get_db


def register_admin_routes(app):
    # ─── 带图 Excel 导出任务 ──────────────────────────────────────
    @app.route("/api/admin/export-tasks", methods=["GET"])
    @login_required
    def admin_export_tasks():
        page = request.args.get("page", 1, type=int)
        status = (request.args.get("status") or "").strip()
        per_page = 15
        offset = (page - 1) * per_page
        where, params = "", []
        if status in ("queued", "processing", "done", "failed"):
            where, params = " WHERE status=?", [status]
        with get_db() as conn:
            total = conn.execute(f"SELECT COUNT(*) FROM export_tasks{where}", params).fetchone()[0]
            counts = {
                r["status"]: r["c"]
                for r in conn.execute("SELECT status, COUNT(*) AS c FROM export_tasks GROUP BY status").fetchall()
            }
            rows = conn.execute(
                f"SELECT id, device_hash, types, status, error, lang, created_at, started_at, finished_at, downloaded "
                f"FROM export_tasks{where} ORDER BY created_at DESC LIMIT ? OFFSET ?",
                (*params, per_page, offset),
            ).fetchall()
        return jsonify({
            "tasks": [dict(r) for r in rows],
            "counts": counts,
            "total": total,
            "page": page,
            "per_page": per_page,
        })

    # ─── 导出功能分析 ─────────────────────────────────────────────
    @app.route("/api/admin/export/stats", methods=["GET"])
    @login_required
    def admin_export_stats():
        with get_db() as conn:
            total = conn.execute("SELECT COUNT(*) FROM export_tasks").fetchone()[0]
            devices = conn.execute("SELECT COUNT(DISTINCT device_hash) FROM export_tasks").fetchone()[0]
            type_dist = [
                {"types": r["types"], "count": r["c"]}
                for r in conn.execute("SELECT types, COUNT(*) AS c FROM export_tasks GROUP BY types ORDER BY c DESC").fetchall()
            ]
            status_counts = {
                r["status"]: r["c"]
                for r in conn.execute("SELECT status, COUNT(*) AS c FROM export_tasks GROUP BY status").fetchall()
            }
            rows = conn.execute(
                "SELECT started_at, finished_at FROM export_tasks "
                "WHERE status='done' AND started_at IS NOT NULL AND finished_at IS NOT NULL"
            ).fetchall()
        durations = []
        for r in rows:
            try:
                d = (datetime.fromisoformat(r["finished_at"]) - datetime.fromisoformat(r["started_at"])).total_seconds()
                if d >= 0:
                    durations.append(d)
            except (ValueError, TypeError):
                pass
        done = status_counts.get("done", 0)
        failed = status_counts.get("failed", 0)
        finished = done + failed
        return jsonify({
            "total_tasks": total,
            "unique_devices": devices,
            "type_dist": type_dist,
            "done": done,
            "failed": failed,
            "success_rate": round(done / finished * 100, 1) if finished else 0,
            "avg_duration_seconds": round(sum(durations) / len(durations), 1) if durations else 0,
        })

    # ─── 更新日志 ────────────────────────────────────────────────
    @app.route("/api/admin/changelog", methods=["GET"])
    @login_required
    def get_changelog():
        with get_db() as conn:
            rows = conn.execute(
                "SELECT id, version, date, features, sort_order FROM changelog WHERE is_deleted = 0 ORDER BY sort_order DESC"
            ).fetchall()
        return jsonify({"items": [{
            "id": r["id"], "version": r["version"], "date": r["date"],
            "features": json.loads(r["features"] or "[]"), "sort_order": r["sort_order"]
        } for r in rows]})

    @app.route("/api/admin/changelog", methods=["POST"])
    @login_required
    def save_changelog():
        data = request.get_json(silent=True) or {}
        item_id = data.get("id")
        version = (data.get("version") or "").strip()
        date = (data.get("date") or "").strip()
        features = data.get("features", [])
        sort_order = data.get("sort_order", 0)
        if not version or not date:
            return jsonify({"error": "version and date required"}), 400
        now = datetime.now(timezone.utc).isoformat()
        with get_db() as conn:
            if item_id:
                conn.execute(
                    "UPDATE changelog SET version=?, date=?, features=?, sort_order=? WHERE id=?",
                    (version, date, json.dumps(features), sort_order, item_id),
                )
            else:
                conn.execute(
                    "INSERT INTO changelog (version, date, features, sort_order, created_at) VALUES (?,?,?,?,?)",
                    (version, date, json.dumps(features), sort_order, now),
                )
            conn.commit()
        return jsonify({"status": "ok"})

    @app.route("/api/admin/changelog/<int:item_id>", methods=["DELETE"])
    @login_required
    def delete_changelog(item_id):
        with get_db() as conn:
            # 软删除：保留数据，仅标记 is_deleted
            conn.execute("UPDATE changelog SET is_deleted=1 WHERE id=?", (item_id,))
            conn.commit()
        return jsonify({"status": "ok"})

    # ─── 增强视频校验值管理 ────────────────────────────────────
    @app.route("/api/admin/enhance-video", methods=["GET"])
    @login_required
    def get_enhance_video():
        with get_db() as conn:
            row = conn.execute(
                "SELECT value, updated_at FROM kv_settings WHERE key=?", ("enhance_video_value",)
            ).fetchone()
        return jsonify({
            "value": row["value"] if row else "",
            "updated_at": row["updated_at"] if row else None,
        })

    @app.route("/api/admin/enhance-video", methods=["PUT"])
    @login_required
    def update_enhance_video():
        data = request.get_json(silent=True) or {}
        value = data.get("value", "")
        if not isinstance(value, str):
            return jsonify({"error": "value must be string"}), 400
        now = datetime.now(timezone.utc).isoformat()
        with get_db() as conn:
            conn.execute(
                "INSERT INTO kv_settings (key, value, updated_at) VALUES (?,?,?) "
                "ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at",
                ("enhance_video_value", value, now),
            )
            conn.commit()
        return jsonify({"status": "ok"})

    # ─── 公开更新日志 ──────────────────────────────────────────
    @app.route("/api/changelog", methods=["GET", "OPTIONS"])
    def public_changelog():
        if request.method == "OPTIONS":
            resp = app.make_default_options_response()
        else:
            with get_db() as conn:
                rows = conn.execute(
                    "SELECT version, date, features FROM changelog WHERE is_deleted = 0 ORDER BY sort_order DESC"
                ).fetchall()
            resp = jsonify({"items": [{
                "version": r["version"], "date": r["date"],
                "features": json.loads(r["features"] or "[]")
            } for r in rows]})
        resp.headers["Access-Control-Allow-Origin"] = "*"
        resp.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
        resp.headers["Access-Control-Allow-Headers"] = "Content-Type"
        return resp

    # ─── 崩溃上报管理 ─────────────────────────────────────────
    @app.route("/api/admin/crashes", methods=["GET"])
    @login_required
    def admin_crashes():
        """按签名聚合：次数、影响设备数、涉及版本、最近发生"""
        with get_db() as conn:
            rows = conn.execute("""
                SELECT signature,
                       COUNT(*) AS count,
                       COUNT(DISTINCT device_hash) AS devices,
                       MAX(created_at) AS last_seen,
                       MIN(created_at) AS first_seen,
                       (SELECT error FROM crash_reports c2 WHERE c2.signature = c.signature
                        ORDER BY created_at DESC LIMIT 1) AS sample
                FROM crash_reports c
                GROUP BY signature ORDER BY last_seen DESC
            """).fetchall()
            versions = conn.execute("""
                SELECT signature, app_version, COUNT(*) AS c FROM crash_reports
                WHERE app_version != '' GROUP BY signature, app_version
            """).fetchall()
        ver_map = {}
        for v in versions:
            ver_map.setdefault(v["signature"], []).append(
                {"version": v["app_version"], "count": v["c"]})
        items = []
        for r in rows:
            first_line = (r["sample"] or "").split("\n")[0][:120]
            items.append({
                "signature": r["signature"], "count": r["count"], "devices": r["devices"],
                "first_seen": r["first_seen"], "last_seen": r["last_seen"],
                "title": first_line,
                "versions": sorted(ver_map.get(r["signature"], []),
                                   key=lambda x: -x["count"])[:5],
            })
        return jsonify({"items": items})

    @app.route("/api/admin/crashes/<signature>", methods=["GET"])
    @login_required
    def admin_crash_detail(signature):
        with get_db() as conn:
            rows = conn.execute(
                "SELECT id, device_hash, app_version, device_type, error, created_at "
                "FROM crash_reports WHERE signature=? ORDER BY created_at DESC LIMIT 100",
                (signature,),
            ).fetchall()
        return jsonify({"items": [dict(r) for r in rows]})

    @app.route("/api/admin/crashes/<signature>", methods=["DELETE"])
    @login_required
    def admin_crash_delete(signature):
        with get_db() as conn:
            conn.execute("DELETE FROM crash_reports WHERE signature=?", (signature,))
            conn.commit()
        return jsonify({"status": "ok"})

    @app.route("/api/admin/crashes/id/<int:item_id>", methods=["DELETE"])
    @login_required
    def admin_crash_delete_one(item_id):
        """删除单条日志记录（详情弹窗内逐条清理）"""
        with get_db() as conn:
            conn.execute("DELETE FROM crash_reports WHERE id=?", (item_id,))
            conn.commit()
        return jsonify({"status": "ok"})

    # ─── 意见反馈管理 ─────────────────────────────────────────
    @app.route("/api/admin/feedback", methods=["GET"])
    @login_required
    def admin_feedback():
        status = (request.args.get("status") or "").strip()
        sql = ("SELECT id, device_hash, content, contact, app_version, device_type, "
               "status, reply, created_at, updated_at FROM feedback")
        args = ()
        if status in ("pending", "done"):
            sql += " WHERE status=?"
            args = (status,)
        sql += " ORDER BY CASE status WHEN 'pending' THEN 0 ELSE 1 END, created_at DESC LIMIT 300"
        with get_db() as conn:
            rows = conn.execute(sql, args).fetchall()
            counts = conn.execute(
                "SELECT status, COUNT(*) AS c FROM feedback GROUP BY status").fetchall()
        return jsonify({
            "items": [dict(r) for r in rows],
            "counts": {r["status"]: r["c"] for r in counts},
        })

    @app.route("/api/admin/feedback/<int:item_id>", methods=["PUT"])
    @login_required
    def admin_feedback_update(item_id):
        data = request.get_json(silent=True) or {}
        status = (data.get("status") or "").strip()
        reply = (data.get("reply") or "").strip()[:2000]
        if status not in ("pending", "done"):
            return jsonify({"error": "invalid status"}), 400
        now = datetime.now(timezone.utc).isoformat()
        with get_db() as conn:
            conn.execute(
                "UPDATE feedback SET status=?, reply=?, updated_at=? WHERE id=?",
                (status, reply, now, item_id),
            )
            conn.commit()
        return jsonify({"status": "ok"})

    @app.route("/api/admin/feedback/<int:item_id>", methods=["DELETE"])
    @login_required
    def admin_feedback_delete(item_id):
        with get_db() as conn:
            conn.execute("DELETE FROM feedback WHERE id=?", (item_id,))
            conn.commit()
        return jsonify({"status": "ok"})
