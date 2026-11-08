"""stats.db 自动备份：每天上午/下午各一份，保留最近 N 天"""
import os
import sqlite3
import threading
import time
from datetime import datetime

from config import DB_PATH, BASE_DIR, BACKUP_HOURS, BACKUP_KEEP_DAYS

BACKUP_DIR = os.path.join(BASE_DIR, "backups")


def _backup_once():
    os.makedirs(BACKUP_DIR, exist_ok=True)
    name = "stats_" + datetime.now().strftime("%Y%m%d_%H%M") + ".db"
    dest = os.path.join(BACKUP_DIR, name)
    # 用 SQLite 在线备份 API，WAL 模式下直接复制文件会丢未 checkpoint 的数据
    src = sqlite3.connect(DB_PATH)
    try:
        dst = sqlite3.connect(dest)
        try:
            src.backup(dst)
        finally:
            dst.close()
    finally:
        src.close()


def _cleanup_old():
    cutoff = time.time() - BACKUP_KEEP_DAYS * 86400
    try:
        names = os.listdir(BACKUP_DIR)
    except OSError:
        return
    for name in names:
        if not (name.startswith("stats_") and name.endswith(".db")):
            continue
        path = os.path.join(BACKUP_DIR, name)
        try:
            if os.path.getmtime(path) < cutoff:
                os.remove(path)
        except OSError:
            pass


def _backup_loop():
    done_slots = set()
    while True:
        now = datetime.now()
        slot = now.strftime("%Y%m%d_") + str(now.hour)
        if now.hour in BACKUP_HOURS and slot not in done_slots:
            try:
                _backup_once()
                _cleanup_old()
                print(f"[backup] 已备份到 {BACKUP_DIR}")
            except Exception as e:
                print(f"[backup] 备份失败: {e}")
            # 只保留今天的 slot 记录，防止集合无限增长
            done_slots = {slot}
        time.sleep(60)


def start_backup_thread():
    threading.Thread(target=_backup_loop, daemon=True).start()
