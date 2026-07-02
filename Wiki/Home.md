# MookNote Wiki

极简风格的观影阅读笔记应用，基于 Flutter 框架开发。

## 功能概览

- **影视管理** — 增删改查、影评、海报墙、豆瓣链接爬取
- **书籍管理** — 增删改查、书评、摘抄
- **笔记管理** — Markdown 笔记、标签、图片
- **EPUB 阅读** — 本地 EPUB 阅读、书摘、高亮
- **数据同步** — 服务端实时同步、WebDAV 同步、自动本地备份
- **回收站** — 软删除 + 恢复/彻底删除
- **标签管理** — 影视类型、书籍类型、笔记标签统一管理
- **统计分析** — 观影/阅读数据统计
- **布局设置** — 影视墙/书架模式、网格/列表/大图卡片布局

## 技术栈

| 层级 | 技术 |
|------|------|
| 框架 | Flutter 3.5+, Dart |
| 状态管理 | Provider (ChangeNotifier) |
| 本地存储 | SQLite (sqflite) |
| 远程同步 | HTTP API (http 包) |
| 后端 | Python Flask |
| 主题 | Material 3, 极简黑白灰 |

## Wiki 目录

- [快速开始](Getting-Started.md) — 环境配置、安装与运行
- [整体架构](Architecture.md) — 分层架构、目录结构、启动流程
- [数据模型](Data-Models.md) — 模型定义、数据库表结构、迁移链
- [状态管理](State-Management.md) — AppProvider、Tab 状态、分页加载
- [数据访问层](Data-Access-Layer.md) — DAO 模式、软删除、回收站
- [图片存储](Image-Storage.md) — 图片路径管理、存储结构
- [同步系统](Sync-System.md) — 服务端同步、WebDAV、自动备份
- [服务端 API](Server-API.md) — Flask 后端、API 端点、激活码机制
- [页面与路由](Pages-and-Navigation.md) — 页面结构、路由表、过渡动画、添加按钮规范
- [主题与 UI](Theme-and-UI.md) — 主题配置、布局设置界面、标签选择面板、共享组件
- [用户偏好](User-Preferences.md) — SharedPreferences 配置项、布局设置、排序方式
