package com.example.zhixue.backend;

import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/**
 * 日期/星期/连续打卡天数 工具类。
 * 所有日期字符串统一使用 yyyy-MM-dd（严格补零），保证字符串字典序与时间顺序一致，可直接比较。
 */
public final class DateUtils {

    public static final String PATTERN = "yyyy-MM-dd";

    private DateUtils() {}

    private static SimpleDateFormat fmtObj() {
        return new SimpleDateFormat(PATTERN, Locale.CHINA);
    }

    /** 当前日期字符串 yyyy-MM-dd */
    public static String today() {
        return fmt(Calendar.getInstance());
    }

    /** Calendar -> yyyy-MM-dd */
    public static String fmt(Calendar c) {
        return fmtObj().format(c.getTime());
    }

    /** yyyy-MM-dd -> Calendar（解析失败抛 RuntimeException） */
    public static Calendar parseYMD(String dateYMD) {
        try {
            java.util.Date d = fmtObj().parse(dateYMD);
            Calendar c = Calendar.getInstance(Locale.CHINA);
            c.setTime(d);
            return c;
        } catch (Exception e) {
            throw new RuntimeException("日期解析失败: " + dateYMD, e);
        }
    }

    /**
     * ISO 星期：周一=1，周二=2 ... 周日=7。
     * Calendar 的 DAY_OF_WEEK 周日=1, 周一=2 ... 周六=7，需转换。
     */
    public static int isoWeekday(Calendar c) {
        int d = c.get(Calendar.DAY_OF_WEEK);
        return d == Calendar.SUNDAY ? 7 : d - 1;
    }

    /** 当前 ISO 星期（周一=1...周日=7） */
    public static int todayIsoWeekday() {
        return isoWeekday(Calendar.getInstance());
    }

    /**
     * 判断某任务在某日期是否为执行日：
     * 1) dateYMD 在 [startDate, endDate] 闭区间（字符串比较）
     * 2) 该日 ISO 星期 ∈ weekDays
     */
    public static boolean isScheduledOn(String dateYMD, String startDate, String endDate, List<Integer> weekDays) {
        if (dateYMD.compareTo(startDate) < 0 || dateYMD.compareTo(endDate) > 0) {
            return false;
        }
        int iso = isoWeekday(parseYMD(dateYMD));
        return weekDays.contains(iso);
    }

    /** 日期字符串减一天 */
    public static String minusOneDay(String dateYMD) {
        Calendar c = parseYMD(dateYMD);
        c.add(Calendar.DAY_OF_MONTH, -1);
        return fmt(c);
    }

    /** 日期字符串加一天 */
    public static String plusOneDay(String dateYMD) {
        Calendar c = parseYMD(dateYMD);
        c.add(Calendar.DAY_OF_MONTH, 1);
        return fmt(c);
    }

    /**
     * 连续打卡天数：从今日起向前连续命中打卡日期的天数；
     * 若今日无打卡则从昨日起算（早晨未打卡不立即清零）。
     */
    public static int calcStreak(Set<String> checkinDates) {
        if (checkinDates == null || checkinDates.isEmpty()) return 0;
        String today = today();
        String cursor = checkinDates.contains(today) ? today : minusOneDay(today);
        int streak = 0;
        // 防御性上限，避免异常死循环
        int guard = 0;
        while (checkinDates.contains(cursor) && guard < 100000) {
            streak++;
            cursor = minusOneDay(cursor);
            guard++;
        }
        return streak;
    }

    /** 给定年份月份，返回该月所有日期的 yyyy-MM-dd 列表 */
    public static java.util.List<String> daysOfMonth(int year, int month) {
        java.util.List<String> out = new java.util.ArrayList<>();
        Calendar c = Calendar.getInstance(Locale.CHINA);
        c.set(year, month - 1, 1);
        int lastDay = c.getActualMaximum(Calendar.DAY_OF_MONTH);
        for (int i = 1; i <= lastDay; i++) {
            c.set(year, month - 1, i);
            out.add(fmt(c));
        }
        return out;
    }
}
