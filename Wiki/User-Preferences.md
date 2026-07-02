# 用户偏好

## UserPrefs

`lib/utils/user_prefs.dart` — SharedPreferences 单例包装器。

### 布局设置

| 偏好项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `movieLayoutStyle` | int | 0 | 影视布局：0=海报网格, 1=列表, 2=大图卡片 |
| `bookLayoutStyle` | int | 0 | 阅读布局：0=封面网格, 1=列表 |
| `noteLayoutStyle` | int | 0 | 笔记布局：0=列表, 1=瀑布流, 2=时间线 |
| `movieWallMode` | bool | false | 影视墙模式：显示全部影片，不区分状态 |
| `bookshelfMode` | bool | false | 书架模式：显示全部书籍，不区分状态 |

### 排序方式

| 偏好项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `movieSortMode` | int | 0 | 影视排序：0=更新时间, 1=创建时间, 2=评分 |
| `bookSortMode` | int | 0 | 书籍排序：0=更新时间, 1=创建时间, 2=评分 |
| `noteSortMode` | int | 0 | 笔记排序：0=更新时间, 1=创建时间 |

### 主界面标签显示

| 偏好项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `showMovieTab` | bool | true | 显示影视标签 |
| `showBookTab` | bool | true | 显示阅读标签 |
| `showNoteTab` | bool | true | 显示笔记标签 |
| `showNotePlusTab` | bool | false | 显示 Note Plus 标签 |
| `defaultMainTabIndex` | int | 0 | 默认启动标签 |

### 主题设置

| 偏好项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `themeMode` | int | 0 | 0=跟随系统, 1=浅色, 2=深色 |
| `colorSchemeIndex` | int | 0 | 配色方案：0=经典, 1=靛蓝, 2=薄荷, 3=琥珀, 4=玫瑰, 5=紫罗兰 |
| `fontFamily` | String | '' | 字体，空字符串=系统默认 |

### 侧边栏功能开关

| 偏好项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `showSidebarHeatmap` | bool | true | 热力图 |
| `showSidebarRecent` | bool | true | 最近添加 |
| `showSidebarEncounter` | bool | true | 随机邂逅 |
| `showSidebarStroll` | bool | true | 漫步 |
| `showSidebarCalendar` | bool | true | 日历 |
| `showSidebarPerson` | bool | true | 人物 |
| `showSidebarTags` | bool | true | 标签 |
| `showSidebarMdReader` | bool | false | Markdown 阅读器 |
| `showSidebarEpub` | bool | true | EPUB 阅读器 |

### 其他设置

| 偏好项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `hideBottomNavOnScroll` | bool | true | 滚动时隐藏底部导航栏 |
| `showExactReleaseDate` | bool | true | 上映日期显示到日（false=显示到月） |
| `detailPageStyle` | int | 0 | 详情页样式：0=标准, 1=叠层 |
| `epubFontSize` | double | 18.0 | EPUB 阅读器字体大小 |
| `epubViewMode` | int | 0 | EPUB 书架视图：0=宽松, 1=紧凑 |
| `highlightsViewMode` | int | 0 | 摘抄视图：0=瀑布流, 1=列表 |

[返回首页](Home.md)
