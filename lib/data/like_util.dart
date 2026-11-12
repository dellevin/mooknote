/// SQLite LIKE 转义工具：使用户输入按字面量匹配，
/// 避免输入中的 % / _ 被当作通配符。
///
/// SQL 中须配合 `ESCAPE '\'` 子句使用，参数用 [likePattern] 构造。
library;

/// 转义反斜杠与 LIKE 通配符
String escapeLike(String input) => input
    .replaceAll('\\', '\\\\')
    .replaceAll('%', '\\%')
    .replaceAll('_', '\\_');

/// 构造两端模糊匹配的 LIKE 参数（已转义）
String likePattern(String input) => '%${escapeLike(input)}%';
