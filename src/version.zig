const std = @import("std");
const c = @import("c");

/// Return OpenCV version as a string.
pub fn openCVVersion() []const u8 {
    return std.mem.span(c.openCVVersion());
}

test "show version" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const parseFloat = std.fmt.parseFloat;

    const version = openCVVersion();

    const result = std.process.run(allocator, testing.io, .{
        .argv = &.{ "pkg-config", "--modversion", "opencv4" },
    }) catch {
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    const actual_version = result.stdout;

    try testing.expectEqual(parseFloat(f32, actual_version), parseFloat(f32, version));
}

//*    implementation done
//*    pub extern fn openCVVersion(...) [*c]const u8;
