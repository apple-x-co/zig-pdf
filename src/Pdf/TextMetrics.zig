const Self = @This();

descent: f32,
line_height: f32,
width: f32,

pub fn init(descent: f32, line_height: f32, width: f32) Self {
    return .{
        .descent = descent,
        .line_height = line_height,
        .width = width,
    };
}
