const Self = @This();
const std = @import("std");

year: u16,
month: u8,
day: u8,
hours: u8,
minutes: u8,
seconds: u8,

pub fn init(secs: u64) Self {
    const epoch = std.time.epoch.EpochSeconds{ .secs = secs };
    const epoch_day = epoch.getEpochDay();
    const year_day = epoch_day.calculateYearDay();
    const month_day = year_day.calculateMonthDay();
    const day_seconds = epoch.getDaySeconds();

    return .{
        .year = year_day.year,
        .month = month_day.month.numeric(),
        .day = month_day.day_index + 1,
        .hours = day_seconds.getHoursIntoDay(),
        .minutes = day_seconds.getMinutesIntoHour(),
        .seconds = day_seconds.getSecondsIntoMinute(),
    };
}

pub fn now() Self {
    return init(@intCast(u64, std.time.timestamp()));
}

test "date" {
    // Epoch timestamp: 1672628645
    // Timestamp in milliseconds: 1672628645000
    // Date and time (GMT): 2023年1月2日 Monday 03:04:05
    // Date and time (your time zone): 2023年1月2日 月曜日 12:04:05 GMT+09:00
    const date = init(1672628645);
    try std.testing.expectEqual(@intCast(u16, 2023), date.year);
    try std.testing.expectEqual(@intCast(u8, 1), date.month);
    try std.testing.expectEqual(@intCast(u8, 2), date.day);
    try std.testing.expectEqual(@intCast(u8, 3), date.hours);
    try std.testing.expectEqual(@intCast(u8, 4), date.minutes);
    try std.testing.expectEqual(@intCast(u8, 5), date.seconds);
}
