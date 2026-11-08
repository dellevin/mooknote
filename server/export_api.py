"""带图 Excel 导出 API

流程：客户端上传精简数据包（mooknote.db + images/）→ 建任务排队 →
后台 worker 逐个处理（openpyxl + Pillow 嵌图）→ 客户端轮询状态 → 下载结果。
鉴权：影视/书籍两个增强搜索 Token 都有效才放行（服务端调 vipapi 校验）。
"""
import hashlib
import json
import os
import shutil
import sqlite3
import tempfile
import threading
import time
import urllib.parse
import urllib.request
import uuid
import zipfile
from datetime import datetime, timezone

from flask import jsonify, request, send_file

from config import BASE_DIR, VIP_API_BASE

EXPORT_ROOT = os.path.join(BASE_DIR, "export_workspace")
MAX_UPLOAD_BYTES = 300 * 1024 * 1024  # 上传包上限
RESULT_TTL_SECONDS = 30 * 60          # 生成结果保留时长（超时未下载即清理）
STUCK_TASK_SECONDS = 60 * 60          # 排队/处理中超过此时长视为卡死
VALID_TYPES = {"movies", "books", "games", "notes"}

# 封面缩略图最大像素（控制 xlsx 体积）
# 单元格内图片的"显示尺寸"上限（仅影响排版，不压缩图片本身）
IMG_DISPLAY_MAX_W = 80
IMG_DISPLAY_MAX_H = 110


def _now_iso():
    return datetime.now(timezone.utc).isoformat()


def _hash_device(device_hash: str) -> str:
    return hashlib.sha256(device_hash.encode()).hexdigest()


# ─── Token 校验（vipapi，两个都必须有效） ──────────────────────────────────

def _check_token(token: str, type_: str):
    """返回 (是否有效, 服务端消息)"""
    try:
        url = f"{VIP_API_BASE}/api/token/check?" + urllib.parse.urlencode({"token": token, "type": type_})
        with urllib.request.urlopen(url, timeout=8) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        if data.get("code") == 0 and isinstance(data.get("data"), dict):
            return bool(data["data"].get("valid")), str(data["data"].get("messageString") or "")
        return False, "验证服务返回异常"
    except Exception:
        return False, "Token 验证服务不可用"


# ─── 任务处理 ──────────────────────────────────────────────────────────────

def _claim_task():
    """原子认领一条排队任务（BEGIN IMMEDIATE 保证多进程/多线程不重复领取）"""
    from database import get_db
    conn = get_db()
    try:
        conn.execute("BEGIN IMMEDIATE")
        row = conn.execute(
            "SELECT id FROM export_tasks WHERE status='queued' ORDER BY created_at LIMIT 1"
        ).fetchone()
        if row is None:
            conn.rollback()
            return None
        conn.execute(
            "UPDATE export_tasks SET status='processing', started_at=? WHERE id=?",
            (_now_iso(), row["id"]),
        )
        conn.commit()
        return row["id"]
    except Exception:
        conn.rollback()
        return None
    finally:
        conn.close()


# 新任务入队时唤醒 worker，避免空转轮询；timeout 兜底防丢失唤醒
_task_event = threading.Event()


def _worker_loop():
    while True:
        _task_event.clear()
        task_id = _claim_task()
        while task_id is not None:
            _process_task(task_id)
            task_id = _claim_task()
        _task_event.wait(timeout=30)


def _safe_extract(zip_path: str, dest_dir: str):
    """解压并防御 zip slip（路径穿越）"""
    with zipfile.ZipFile(zip_path) as zf:
        for member in zf.namelist():
            normalized = os.path.normpath(member)
            if normalized.startswith("..") or os.path.isabs(normalized) or normalized.startswith("/"):
                raise ValueError(f"非法压缩包路径: {member}")
        zf.extractall(dest_dir)


def _build_image_index(extract_dir: str):
    """遍历解压出的 images/，建 逻辑路径→绝对路径 与 文件名→绝对路径 两个索引"""
    by_logical, by_name = {}, {}
    images_root = os.path.join(extract_dir, "images")
    if not os.path.isdir(images_root):
        return by_logical, by_name
    for dirpath, _, filenames in os.walk(images_root):
        for name in filenames:
            full = os.path.join(dirpath, name)
            logical = os.path.relpath(full, images_root).replace(os.sep, "/")
            by_logical.setdefault(logical, full)
            by_name.setdefault(name, full)
    return by_logical, by_name


def _resolve_image(db_value: str, by_logical: dict, by_name: dict):
    """db 里存的是各设备绝对路径，取 /images/ 之后的逻辑部分匹配，退化为按文件名匹配"""
    normalized = str(db_value).replace("\\", "/")
    idx = normalized.find("/images/")
    if idx >= 0:
        hit = by_logical.get(normalized[idx + 8:])
        if hit:
            return hit
    return by_name.get(os.path.basename(normalized))


def _prepare_image(src_path: str, work_dir: str, tag: str):
    """准备嵌入 Excel 的图片：不缩放、不压缩，保留原始分辨率。
    jpg/png/gif 直接用原文件；webp 等 Excel 不支持的格式原尺寸转 PNG。
    返回 (嵌入用文件路径, 原图宽, 原图高)，失败返回 None"""
    from PIL import Image as PILImage
    ext = os.path.splitext(src_path)[1].lower()
    try:
        if ext in (".jpg", ".jpeg", ".png", ".gif"):
            with PILImage.open(src_path) as img:
                return src_path, img.width, img.height
        with PILImage.open(src_path) as img:
            w, h = img.width, img.height
            out = os.path.join(work_dir, f"img_{tag}.png")
            img.save(out, "PNG")
            return out, w, h
    except Exception:
        return None


def _jlist(value):
    """JSON 数组字符串 → 顿号连接"""
    if not value:
        return ""
    try:
        items = json.loads(value)
        if isinstance(items, list):
            return "、".join(str(x) for x in items if x)
    except Exception:
        pass
    return ""


def _col(row, name, default=""):
    """防御性取列：列不存在或为 NULL 时返回默认"""
    try:
        v = row[name]
    except (KeyError, IndexError):
        return default
    return default if v is None else v


def _fmt_date(v):
    s = str(v or "")
    return s[:10]


def _fmt_datetime(v):
    return str(v or "")[:16].replace("T", " ")


# 表头与状态/分类映射（中英两套，按客户端 lang 选择）
_L = {
    "zh": {
        "sheets": {"movies": "影视", "books": "阅读", "games": "游戏", "notes": "笔记"},
        "cover": "封面", "image": "图片", "yes": "是", "no": "否",
        "movie_status": {"watched": "已看", "watching": "在看", "want_to_watch": "想看"},
        "movie_category": {"movie": "电影", "tv": "电视剧", "anime": "动漫", "variety": "综艺",
                           "documentary": "纪录片", "short": "短片", "other": "其他"},
        "book_status": {"read": "已读", "reading": "在读", "want_to_read": "想读"},
        "game_status": {"completed": "已通关", "playing": "在玩", "want_to_play": "想玩", "abandoned": "弃游"},
        "game_category": {"digital": "数字版", "cartridge": "卡带", "disc": "光盘"},
        "headers": {
            "movies": ["名称", "类别", "状态", "评分", "导演", "编剧", "主演", "类型", "别名",
                       "上映时间", "观看日期", "观看次数", "时长(分钟)", "简介", "创建时间", "更新时间"],
            "books": ["名称", "状态", "评分", "作者", "译者", "别名", "出版社", "类型", "ISBN",
                      "出版时间", "开始阅读", "读完时间", "阅读次数", "简介", "创建时间", "更新时间"],
            "games": ["名称", "状态", "评分", "分类", "平台", "版本", "类型", "游玩时长(小时)", "游玩时长(分钟)",
                      "游玩次数", "开发者", "发售时间", "购买平台", "购买日期", "购买价格", "简介", "创建时间", "更新时间"],
            "notes": ["标题", "内容", "内容类型", "标签", "图片数", "是否置顶", "创建时间", "更新时间"],
        },
        "review_sheets": {"movies": "影评", "books": "书评", "games": "游戏评价"},
        "review_entity": {"movies": "影视名称", "books": "书籍名称", "games": "游戏名称"},
        "review_headers": ["类型", "内容", "评论者", "来源", "评论日期", "创建时间", "更新时间"],
        "review_type": {1: "短评", 2: "长评"},
    },
    "en": {
        "sheets": {"movies": "Movies", "books": "Books", "games": "Games", "notes": "Notes"},
        "cover": "Cover", "image": "Image", "yes": "Yes", "no": "No",
        "movie_status": {"watched": "Watched", "watching": "Watching", "want_to_watch": "Want to Watch"},
        "movie_category": {"movie": "Movie", "tv": "TV Series", "anime": "Anime", "variety": "Variety",
                           "documentary": "Documentary", "short": "Short", "other": "Other"},
        "book_status": {"read": "Read", "reading": "Reading", "want_to_read": "Want to Read"},
        "game_status": {"completed": "Completed", "playing": "Playing", "want_to_play": "Want to Play",
                        "abandoned": "Abandoned"},
        "game_category": {"digital": "Digital", "cartridge": "Cartridge", "disc": "Disc"},
        "headers": {
            "movies": ["Title", "Category", "Status", "Rating", "Directors", "Writers", "Cast", "Genres",
                       "Alt Titles", "Release", "Watch Date", "Watch Count", "Duration(min)", "Summary",
                       "Created", "Updated"],
            "books": ["Title", "Status", "Rating", "Authors", "Translators", "Alt Titles", "Publisher", "Genres",
                      "ISBN", "Published", "Started", "Finished", "Read Count", "Summary", "Created", "Updated"],
            "games": ["Title", "Status", "Rating", "Format", "Platforms", "Versions", "Genres", "Hours", "Minutes",
                      "Play Count", "Developers", "Release", "Purchase Platforms", "Purchase Date", "Price",
                      "Summary", "Created", "Updated"],
            "notes": ["Title", "Content", "Content Type", "Tags", "Images", "Pinned", "Created", "Updated"],
        },
        "review_sheets": {"movies": "Reviews", "books": "Reviews", "games": "Reviews"},
        "review_entity": {"movies": "Movie Title", "books": "Book Title", "games": "Game Title"},
        "review_headers": ["Type", "Content", "Reviewer", "Source", "Review Date", "Created", "Updated"],
        "review_type": {1: "Short", 2: "Long"},
    },
}


def _row_movies(row, L):
    values = [
        _col(row, "title"),
        L["movie_category"].get(_col(row, "category"), _col(row, "category")),
        L["movie_status"].get(_col(row, "status"), _col(row, "status")),
        _col(row, "rating"),
        _jlist(_col(row, "directors")), _jlist(_col(row, "writers")), _jlist(_col(row, "actors")),
        _jlist(_col(row, "genres")), _jlist(_col(row, "alternate_titles")),
        _fmt_date(_col(row, "release_date")), _fmt_date(_col(row, "watch_date")),
        _col(row, "watch_count", 0), _col(row, "duration", 0),
        _col(row, "summary"),
        _fmt_datetime(_col(row, "created_at")), _fmt_datetime(_col(row, "updated_at")),
    ]
    return values, _col(row, "poster_path")


def _row_books(row, L):
    values = [
        _col(row, "title"),
        L["book_status"].get(_col(row, "status"), _col(row, "status")),
        _col(row, "rating"),
        _jlist(_col(row, "authors")), _jlist(_col(row, "translators")),
        _jlist(_col(row, "alternate_titles")),
        _col(row, "publisher"), _jlist(_col(row, "genres")), _col(row, "isbn"),
        _fmt_date(_col(row, "publish_date")), _fmt_date(_col(row, "start_date")),
        _fmt_date(_col(row, "finish_date")),
        _col(row, "read_count", 0),
        _col(row, "summary"),
        _fmt_datetime(_col(row, "created_at")), _fmt_datetime(_col(row, "updated_at")),
    ]
    return values, _col(row, "cover_path")


def _row_games(row, L):
    values = [
        _col(row, "title"),
        L["game_status"].get(_col(row, "status"), _col(row, "status")),
        _col(row, "rating"),
        L["game_category"].get(_col(row, "category"), _col(row, "category")),
        _jlist(_col(row, "platforms")), _jlist(_col(row, "versions")), _jlist(_col(row, "genres")),
        _col(row, "play_time_hours", 0), _col(row, "play_time_minutes", 0), _col(row, "play_count", 0),
        _jlist(_col(row, "developer")),
        _fmt_date(_col(row, "release_date")),
        _jlist(_col(row, "purchase_platforms")), _fmt_date(_col(row, "purchase_date")),
        _col(row, "purchase_price"),
        _col(row, "summary"),
        _fmt_datetime(_col(row, "created_at")), _fmt_datetime(_col(row, "updated_at")),
    ]
    return values, _col(row, "cover_path")


def _row_notes(row, L):
    images = []
    try:
        parsed = json.loads(_col(row, "images") or "[]")
        if isinstance(parsed, list):
            images = [str(x) for x in parsed if x]
    except Exception:
        pass
    values = [
        _col(row, "title"), _col(row, "content"), _col(row, "content_type"),
        _jlist(_col(row, "tags")),
        len(images),
        L["yes"] if _col(row, "is_pinned", 0) else L["no"],
        _fmt_datetime(_col(row, "created_at")), _fmt_datetime(_col(row, "updated_at")),
    ]
    return values, (images[0] if images else "")


_ROW_EXTRACTORS = {"movies": _row_movies, "books": _row_books, "games": _row_games, "notes": _row_notes}


# 评论表映射：导出类型 → (评论表, 外键列, 主表)
_REVIEW_TABLES = {
    "movies": ("movie_reviews", "movie_id", "movies"),
    "books": ("book_reviews", "book_id", "books"),
    "games": ("game_reviews", "game_id", "games"),
}


def _build_xlsx(db_path: str, export_type: str, img_index, out_path: str, lang: str,
                with_reviews: bool = False):
    from openpyxl import Workbook
    from openpyxl.drawing.image import Image as XLImage

    L = _L.get(lang, _L["zh"])
    by_logical, by_name = img_index

    conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    try:
        rows = conn.execute(
            f"SELECT * FROM {export_type} WHERE is_deleted=0 ORDER BY created_at"
        ).fetchall()
    finally:
        conn.close()

    wb = Workbook()
    ws = wb.active
    ws.title = L["sheets"][export_type]
    image_header = L["image"] if export_type == "notes" else L["cover"]
    ws.append([image_header] + L["headers"][export_type])
    ws.column_dimensions["A"].width = (IMG_DISPLAY_MAX_W + 10) / 7

    extractor = _ROW_EXTRACTORS[export_type]
    work_dir = tempfile.mkdtemp(dir=os.path.dirname(out_path))
    try:
        for r_idx, row in enumerate(rows, start=2):
            values, image_value = extractor(row, L)
            ws.append([""] + [str(v) if v is not None else "" for v in values])
            if not image_value:
                continue
            src = _resolve_image(image_value, by_logical, by_name)
            if not src:
                continue
            prepared = _prepare_image(src, work_dir, str(r_idx))
            if not prepared:
                continue
            embed_path, w, h = prepared
            # 显示尺寸按比例收进格子，文件里存的是原图：放大查看依然清晰
            scale = min(IMG_DISPLAY_MAX_W / w, IMG_DISPLAY_MAX_H / h)
            disp_w = max(1, round(w * scale))
            disp_h = max(1, round(h * scale))
            xl_img = XLImage(embed_path)
            xl_img.width = disp_w
            xl_img.height = disp_h
            ws.row_dimensions[r_idx].height = disp_h * 0.75
            ws.add_image(xl_img, f"A{r_idx}")

        # 连同导出评论：追加第二个 sheet（无图片，文本为主）
        if with_reviews and export_type in _REVIEW_TABLES:
            review_table, fk, entity_table = _REVIEW_TABLES[export_type]
            conn2 = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
            conn2.row_factory = sqlite3.Row
            try:
                review_rows = conn2.execute(
                    f"SELECT r.*, e.title AS entity_title FROM {review_table} r "
                    f"LEFT JOIN {entity_table} e ON e.id = r.{fk} "
                    f"WHERE r.is_deleted = 0 ORDER BY r.created_at"
                ).fetchall()
            finally:
                conn2.close()
            ws2 = wb.create_sheet(L["review_sheets"][export_type])
            ws2.append([L["review_entity"][export_type]] + L["review_headers"])
            for rr in review_rows:
                rtype = _col(rr, "review_type", 1)
                ws2.append([
                    _col(rr, "entity_title"),
                    L["review_type"].get(rtype, str(rtype)),
                    _col(rr, "content"), _col(rr, "reviewer"), _col(rr, "source"),
                    _fmt_date(_col(rr, "review_date")),
                    _fmt_datetime(_col(rr, "created_at")), _fmt_datetime(_col(rr, "updated_at")),
                ])

        wb.save(out_path)
    finally:
        # openpyxl 在 save 时才读图片文件，必须保存后再清理
        shutil.rmtree(work_dir, ignore_errors=True)


def _process_task(task_id: str):
    from database import get_db
    with get_db() as conn:
        task = conn.execute("SELECT * FROM export_tasks WHERE id=?", (task_id,)).fetchone()
    if task is None:
        return
    task_dir = os.path.join(EXPORT_ROOT, task_id)
    extract_dir = os.path.join(task_dir, "pack")
    try:
        _safe_extract(task["upload_path"], extract_dir)
        db_path = os.path.join(extract_dir, "mooknote.db")
        if not os.path.exists(db_path):
            raise ValueError("数据包中缺少 mooknote.db")
        out_path = os.path.join(task_dir, "result.xlsx")
        _build_xlsx(db_path, task["types"], _build_image_index(extract_dir), out_path,
                    task["lang"] or "zh", with_reviews=bool(task["with_reviews"]))
        with get_db() as conn:
            conn.execute(
                "UPDATE export_tasks SET status='done', error='', file_path=?, finished_at=? WHERE id=?",
                (out_path, _now_iso(), task_id),
            )
            conn.commit()
    except Exception as e:
        with get_db() as conn:
            conn.execute(
                "UPDATE export_tasks SET status='failed', error=?, finished_at=? WHERE id=?",
                (str(e)[:500], _now_iso(), task_id),
            )
            conn.commit()
    finally:
        # 上传包与解压目录用完即删
        try:
            os.remove(task["upload_path"])
        except OSError:
            pass
        shutil.rmtree(extract_dir, ignore_errors=True)


# ─── 定期清理：结果文件超时即删；任务记录永久保留，不删除 ───────────────────

def _parse_iso(s):
    try:
        return datetime.fromisoformat(s).timestamp()
    except Exception:
        return 0.0


def _clean_once():
    from database import get_db
    now = time.time()
    with get_db() as conn:
        rows = conn.execute("SELECT * FROM export_tasks").fetchall()
        for r in rows:
            task_dir = os.path.join(EXPORT_ROOT, r["id"])
            created = _parse_iso(r["created_at"])
            finished = _parse_iso(r["finished_at"] or "")
            # 卡死任务：排队/处理中超时 → 标记失败
            if r["status"] in ("queued", "processing") and now - created > STUCK_TASK_SECONDS:
                conn.execute(
                    "UPDATE export_tasks SET status='failed', error='任务超时', finished_at=? WHERE id=?",
                    (_now_iso(), r["id"]),
                )
            # 文件清理：已下载、完成超 TTL、失败超 TTL → 删整个任务目录
            if (r["downloaded"]
                    or (finished and now - finished > RESULT_TTL_SECONDS)):
                shutil.rmtree(task_dir, ignore_errors=True)
        conn.commit()


def _cleaner_loop():
    while True:
        time.sleep(300)
        try:
            _clean_once()
        except Exception:
            pass


# ─── 路由 ──────────────────────────────────────────────────────────────────

def register_export_routes(app):
    os.makedirs(EXPORT_ROOT, exist_ok=True)
    threading.Thread(target=_worker_loop, daemon=True).start()
    threading.Thread(target=_cleaner_loop, daemon=True).start()

    @app.route("/api/export/excel", methods=["POST"])
    def export_excel():
        from database import get_db
        device_hash = (request.form.get("device_hash") or "").strip()
        movie_token = (request.form.get("movie_token") or "").strip()
        book_token = (request.form.get("book_token") or "").strip()
        export_type = (request.form.get("type") or "").strip()
        lang = (request.form.get("lang") or "zh").strip()
        with_reviews = 1 if (request.form.get("with_reviews") or "").strip() == "1" else 0

        if not device_hash:
            return jsonify({"code": 1, "message": "device_hash is required"}), 400
        if export_type not in VALID_TYPES:
            return jsonify({"code": 1, "message": "invalid type"}), 400
        if not movie_token or not book_token:
            return jsonify({"code": 2, "message": "需要填写影视和书籍增强搜索 Token"}), 403

        ok_m, msg_m = _check_token(movie_token, "movie")
        if not ok_m:
            return jsonify({"code": 2, "message": f"影视 Token 无效：{msg_m}"}), 403
        ok_b, msg_b = _check_token(book_token, "book")
        if not ok_b:
            return jsonify({"code": 2, "message": f"书籍 Token 无效：{msg_b}"}), 403

        h = _hash_device(device_hash)
        # 同一设备已有排队/处理中的任务 → 直接复用，不重复排队
        with get_db() as conn:
            existing = conn.execute(
                "SELECT id, status FROM export_tasks "
                "WHERE device_hash=? AND status IN ('queued','processing') "
                "ORDER BY created_at DESC LIMIT 1",
                (h,),
            ).fetchone()
        if existing:
            return jsonify({"code": 0, "data": {
                "task_id": existing["id"], "status": existing["status"], "reused": True}})

        file = request.files.get("file")
        if file is None:
            return jsonify({"code": 1, "message": "file is required"}), 400

        task_id = uuid.uuid4().hex
        task_dir = os.path.join(EXPORT_ROOT, task_id)
        os.makedirs(task_dir, exist_ok=True)
        zip_path = os.path.join(task_dir, "upload.zip")
        file.save(zip_path)
        if os.path.getsize(zip_path) > MAX_UPLOAD_BYTES:
            shutil.rmtree(task_dir, ignore_errors=True)
            return jsonify({"code": 1, "message": "数据包过大"}), 413

        with get_db() as conn:
            conn.execute(
                "INSERT INTO export_tasks (id, device_hash, types, status, lang, with_reviews, upload_path, created_at) "
                "VALUES (?,?,?,?,?,?,?,?)",
                (task_id, h, export_type, "queued", lang, with_reviews, zip_path, _now_iso()),
            )
            conn.commit()
        _task_event.set()
        return jsonify({"code": 0, "data": {"task_id": task_id, "status": "queued"}})

    def _load_own_task():
        """按 task_id + device_hash 双重校验取任务，防猜 id 越权"""
        from database import get_db
        task_id = (request.args.get("task_id") or "").strip()
        device_hash = (request.args.get("device_hash") or "").strip()
        if not task_id or not device_hash:
            return None, None
        with get_db() as conn:
            row = conn.execute("SELECT * FROM export_tasks WHERE id=?", (task_id,)).fetchone()
        if row is None or row["device_hash"] != _hash_device(device_hash):
            return None, None
        return task_id, row

    @app.route("/api/export/excel/status", methods=["GET"])
    def export_status():
        from database import get_db
        task_id, row = _load_own_task()
        if row is None:
            return jsonify({"code": 1, "message": "task not found"}), 404
        position = 0
        if row["status"] == "queued":
            with get_db() as conn:
                position = conn.execute(
                    "SELECT COUNT(*) FROM export_tasks WHERE status='queued' AND created_at<=?",
                    (row["created_at"],),
                ).fetchone()[0]
        return jsonify({"code": 0, "data": {
            "status": row["status"], "error": row["error"] or "", "position": position}})

    @app.route("/api/export/excel/download", methods=["GET"])
    def export_download():
        from database import get_db
        task_id, row = _load_own_task()
        if row is None:
            return jsonify({"code": 1, "message": "task not found"}), 404
        if row["status"] != "done" or not row["file_path"] or not os.path.exists(row["file_path"]):
            return jsonify({"code": 1, "message": "file not ready"}), 409
        with get_db() as conn:
            conn.execute("UPDATE export_tasks SET downloaded=1 WHERE id=?", (task_id,))
            conn.commit()
        return send_file(row["file_path"], as_attachment=True,
                         download_name=f"mooknote_{row['types']}_export.xlsx")
