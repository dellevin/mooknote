"""数据库初始化与管理"""
import sqlite3
from datetime import datetime, timezone
from config import DB_PATH


def get_db() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def init_db():
    with get_db() as conn:
        # WAL 模式持久化在 DB 文件中，只需初始化时设置一次
        conn.execute("PRAGMA journal_mode=WAL")

        # 更新日志表
        conn.execute("""
            CREATE TABLE IF NOT EXISTS changelog (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                version TEXT NOT NULL,
                date TEXT NOT NULL,
                features TEXT NOT NULL DEFAULT '[]',
                sort_order INTEGER DEFAULT 0,
                is_deleted INTEGER DEFAULT 0,
                created_at TEXT NOT NULL
            )
        """)

        # 兼容旧表：补充软删除字段
        cl_cols = [r[1] for r in conn.execute("PRAGMA table_info(changelog)").fetchall()]
        if "is_deleted" not in cl_cols:
            conn.execute("ALTER TABLE changelog ADD COLUMN is_deleted INTEGER DEFAULT 0")

        conn.execute("""
            CREATE TABLE IF NOT EXISTS admin_users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
        """)

        # 静态页面表（用户服务协议、隐私政策）
        conn.execute("""
            CREATE TABLE IF NOT EXISTS pages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                slug TEXT UNIQUE NOT NULL,
                title TEXT NOT NULL,
                content TEXT NOT NULL DEFAULT '',
                updated_at TEXT NOT NULL
            )
        """)

        # 通用键值配置表（可在数据库中手动修改值）
        conn.execute("""
            CREATE TABLE IF NOT EXISTS kv_settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL DEFAULT '',
                updated_at TEXT NOT NULL
            )
        """)
        existing_kv = conn.execute("SELECT COUNT(*) FROM kv_settings WHERE key=?", ("enhance_video_value",)).fetchone()[0]
        if existing_kv == 0:
            conn.execute(
                "INSERT INTO kv_settings (key, value, updated_at) VALUES (?, ?, ?)",
                ("enhance_video_value", "", datetime.now(timezone.utc).isoformat()),
            )

        # 带图 Excel 导出任务表：记录谁请求的、状态、结果（文件定期清理，记录保留数天）
        conn.execute("""
            CREATE TABLE IF NOT EXISTS export_tasks (
                id TEXT PRIMARY KEY,
                device_hash TEXT NOT NULL,
                types TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'queued',
                error TEXT DEFAULT '',
                lang TEXT DEFAULT 'zh',
                upload_path TEXT DEFAULT '',
                file_path TEXT DEFAULT '',
                created_at TEXT NOT NULL,
                started_at TEXT,
                finished_at TEXT,
                downloaded INTEGER DEFAULT 0
            )
        """)
        conn.execute("CREATE INDEX IF NOT EXISTS idx_export_status ON export_tasks(status, created_at)")

        # 兼容旧表：补充可能缺失的列
        et_cols = [r[1] for r in conn.execute("PRAGMA table_info(export_tasks)").fetchall()]
        if "with_reviews" not in et_cols:
            conn.execute("ALTER TABLE export_tasks ADD COLUMN with_reviews INTEGER DEFAULT 0")

        # 崩溃上报表（App 端匿名上报，signature 聚合相同崩溃）
        conn.execute("""
            CREATE TABLE IF NOT EXISTS crash_reports (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                signature TEXT NOT NULL,
                device_hash TEXT NOT NULL,
                app_version TEXT DEFAULT '',
                device_type TEXT DEFAULT '',
                error TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
        """)
        conn.execute("CREATE INDEX IF NOT EXISTS idx_crash_sig ON crash_reports(signature)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_crash_time ON crash_reports(created_at)")

        # 意见反馈表（App 端提交，后台回复）
        conn.execute("""
            CREATE TABLE IF NOT EXISTS feedback (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                device_hash TEXT NOT NULL,
                content TEXT NOT NULL,
                contact TEXT DEFAULT '',
                app_version TEXT DEFAULT '',
                device_type TEXT DEFAULT '',
                status TEXT NOT NULL DEFAULT 'pending',
                reply TEXT DEFAULT '',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
        """)
        conn.execute("CREATE INDEX IF NOT EXISTS idx_feedback_status ON feedback(status, created_at)")

        conn.commit()

    # 自动创建默认管理员
    with get_db() as conn:
        existing = conn.execute("SELECT COUNT(*) FROM admin_users").fetchone()[0]
        if existing == 0:
            import hashlib
            default_pw = hashlib.sha256("admin123".encode()).hexdigest()
            conn.execute(
                "INSERT INTO admin_users (username, password_hash, created_at) VALUES (?, ?, ?)",
                ("admin", default_pw, datetime.now(timezone.utc).isoformat()),
            )
            conn.commit()
            print("默认管理员账号: admin / admin123")
