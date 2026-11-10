/// 极简农历转换（公历 1900-01-31 ~ 2100-12-31）
/// 仅提供碎阅日历需要的「农历日 / 月」显示，不做节气、干支
class LunarCalendar {
  LunarCalendar._();

  /// 1900~2100 年农历信息表（经典查表数据）
  static const List<int> _lunarInfo = [
    0x04bd8, 0x04ae0, 0x0a570, 0x054d5, 0x0d260, 0x0d950, 0x16554, 0x056a0, 0x09ad0, 0x055d2,
    0x04ae0, 0x0a5b6, 0x0a4d0, 0x0d250, 0x1d255, 0x0b540, 0x0d6a0, 0x0ada2, 0x095b0, 0x14977,
    0x04970, 0x0a4b0, 0x0b4b5, 0x06a50, 0x06d40, 0x1ab54, 0x02b60, 0x09570, 0x052f2, 0x04970,
    0x6566, 0x0d4a0, 0x0ea50, 0x06e95, 0x05ad0, 0x02b60, 0x186e3, 0x092e0, 0x1c8d7, 0x0c950,
    0x0d4a0, 0x1d8a6, 0x0b550, 0x056a0, 0x1a5b4, 0x025d0, 0x092d0, 0x0d2b2, 0x0a950, 0x0b557,
    0x06ca0, 0x0b550, 0x15355, 0x04da0, 0x0a5b0, 0x14573, 0x052b0, 0x0a9a8, 0x0e950, 0x06aa0,
    0x0aea6, 0x0ab50, 0x04b60, 0x0aae4, 0x0a570, 0x05260, 0x0f263, 0x0d950, 0x05b57, 0x056a0,
    0x096d0, 0x04dd5, 0x04ad0, 0x0a4d0, 0x0d4d4, 0x0d250, 0x0d558, 0x0b540, 0x0b6a0, 0x195a6,
    0x095b0, 0x049b0, 0x0a974, 0x0a4b0, 0x0b27a, 0x06a50, 0x06d40, 0x0af46, 0x0ab60, 0x09570,
    0x04af5, 0x04970, 0x064b0, 0x074a3, 0x0ea50, 0x06b58, 0x055c0, 0x0ab60, 0x096d5, 0x092e0,
    0x0c960, 0x0d954, 0x0d4a0, 0x0da50, 0x07552, 0x056a0, 0x0abb7, 0x025d0, 0x092d0, 0x0cab5,
    0x0a950, 0x0b4a0, 0x0baa4, 0x0ad50, 0x055d9, 0x04ba0, 0x0a5b0, 0x15176, 0x052b0, 0x0a930,
    0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, 0x0a6e6, 0x0a4e0, 0x0d260, 0x0ea65, 0x0d530,
    0x05aa0, 0x076a3, 0x096d0, 0x04afb, 0x04ad0, 0x0a4d0, 0x1d0b6, 0x0d250, 0x0d520, 0x0dd45,
    0x0b5a0, 0x056d0, 0x055b2, 0x049b0, 0x0a577, 0x0a4b0, 0x0aa50, 0x1b255, 0x06d20, 0x0ada0,
    0x14b63, 0x09370, 0x049f8, 0x04970, 0x064b0, 0x168a6, 0x0ea50, 0x06b20, 0x1a6c4, 0x0aae0,
    0x0a2e0, 0x0d2e3, 0x0c960, 0x0d557, 0x0d4a0, 0x0da50, 0x05d55, 0x056a0, 0x0a6d0, 0x055d4,
    0x052d0, 0x0a9b8, 0x0a950, 0x0b4a0, 0x0b6a6, 0x0ad50, 0x055a0, 0x0aba4, 0x0a5b0, 0x052b0,
    0x0b273, 0x06930, 0x07337, 0x06aa0, 0x0ad50, 0x14b55, 0x04b60, 0x0a570, 0x054e4, 0x0d160,
    0x0e968, 0x0d520, 0x0daa0, 0x16aa6, 0x056d0, 0x04ae0, 0x0a9d4, 0x0a2d0, 0x0d150, 0x0f252,
    0x0d520,
  ];

  static const _monthName = ['正', '二', '三', '四', '五', '六', '七', '八', '九', '十', '冬', '腊'];
  static const _dayPrefix = ['初', '十', '廿', '卅'];
  static const _dayNum = ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];

  static int _lYearDays(int y) {
    var sum = 348;
    for (var i = 0x8000; i > 0x8; i >>= 1) {
      sum += (_lunarInfo[y - 1900] & i) != 0 ? 1 : 0;
    }
    return sum + _leapDays(y);
  }

  static int _leapMonth(int y) => _lunarInfo[y - 1900] & 0xf;

  static int _leapDays(int y) {
    if (_leapMonth(y) == 0) return 0;
    return (_lunarInfo[y - 1900] & 0x10000) != 0 ? 30 : 29;
  }

  static int _monthDays(int y, int m) =>
      (_lunarInfo[y - 1900] & (0x10000 >> m)) != 0 ? 30 : 29;

  /// 公历转农历，返回 (月 1-12, 日 1-30, 是否闰月)
  static (int, int, bool) solarToLunar(DateTime solar) {
    final base = DateTime(1900, 1, 31);
    var offset = solar.difference(base).inDays;

    var year = 1900;
    int daysOfYear;
    do {
      daysOfYear = _lYearDays(year);
      offset -= daysOfYear;
      year++;
    } while (offset > 0);
    if (offset < 0) {
      offset += daysOfYear;
      year--;
    }

    final leap = _leapMonth(year);
    var isLeap = false;
    var month = 1;
    int daysOfMonth;
    while (month < 13) {
      if (leap > 0 && month == leap + 1 && !isLeap) {
        isLeap = true;
        month--;
        daysOfMonth = _leapDays(year);
      } else {
        daysOfMonth = _monthDays(year, month);
      }
      offset -= daysOfMonth;
      if (offset < 0) {
        offset += daysOfMonth;
        break;
      }
      if (isLeap && month == leap + 1) isLeap = false;
      month++;
    }
    final day = offset + 1;
    return (month, day, isLeap);
  }

  /// 农历日显示：初一显示月名（如「正月」「腊月」「闰二月」），其余显示日名
  static String dayLabel(DateTime solar) {
    if (solar.year < 1900 || solar.year > 2100) return '';
    final (month, day, isLeap) = solarToLunar(solar);
    if (day == 1) {
      return '${isLeap ? '闰' : ''}${_monthName[month - 1]}月';
    }
    if (day == 10) return '初十';
    if (day == 20) return '二十';
    if (day == 30) return '三十';
    return '${_dayPrefix[day ~/ 10]}${_dayNum[(day % 10) - 1]}';
  }
}
