"""配置常量"""
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(BASE_DIR, "stats.db")
JWT_SECRET = os.environ.get("JWT_SECRET", "mooknote-server-secret-change-me")
JWT_EXPIRE_HOURS = int(os.environ.get("JWT_EXPIRE_HOURS", "72"))
# 崩溃上报保留天数（同一签名仍发生时会重新上报）
CRASH_RETENTION_DAYS = int(os.environ.get("CRASH_RETENTION_DAYS", "90"))
# 已处理反馈保留天数（待处理的一直保留）
FEEDBACK_DONE_RETENTION_DAYS = int(os.environ.get("FEEDBACK_DONE_RETENTION_DAYS", "180"))
# stats.db 自动备份：每天上午/下午各一份，保留最近 N 天
BACKUP_HOURS = tuple(int(h) for h in os.environ.get("BACKUP_HOURS", "6,18").split(","))
BACKUP_KEEP_DAYS = int(os.environ.get("BACKUP_KEEP_DAYS", "5"))
# 增强搜索 Token 校验服务（vipapi）
VIP_API_BASE = os.environ.get("VIP_API_BASE", "http://vipapi.mooknote.iletter.top")
