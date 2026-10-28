const std = @import("std");
const c = @import("c");

pub fn fromCStructsToArrayList(from_array: anytype, from_array_length: i32, comptime ToType: type, allocator: std.mem.Allocator) !std.ArrayList(ToType) {
    const len = @as(usize, @intCast(from_array_length));
    var arr = try std.ArrayList(ToType).initCapacity(allocator, len);
    {
        var i: usize = 0;
        while (i < len) : (i += 1) {
            const elem = blk: {
                const elem = ToType.initFromC(from_array[i]);
                break :blk switch (comptime @typeInfo(@TypeOf(elem))) {
                    .error_union => try elem,
                    else => elem,
                };
            };
            try arr.append(allocator, elem);
        }
    }
    return arr;
}

//  note: cannot implicitly cast double pointer '[*c]?*anyopaque' to anyopaque pointer '?*anyopaque'
pub fn ensurePtrNotNull(ptr: anytype) !@TypeOf(ptr) {
    if (ptr == null) return error.AllocationError;
    return ptr.?;
}

pub fn ensureFileExists(io: std.Io, path: []const u8, allow_zero_byte: bool) !void {
    const stat = std.Io.Dir.cwd().statFile(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("File not found: {s}\n", .{path});
            return error.FileNotFound;
        },
        else => return err,
    };
    if (stat.size == 0 and !allow_zero_byte) {
        std.debug.print("File is empty: {s}\n", .{path});
        return error.FileEmpty;
    }
}

pub fn ensureModelFile(io: std.Io, environ: std.process.Environ, filename: []const u8, allocator: std.mem.Allocator) !void {
    const cache_dir = ".zig-cache/tmp";
    const dest_rel = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ cache_dir, filename });
    defer allocator.free(dest_rel);

    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, cache_dir);

    if (cwd.statFile(io, dest_rel, .{})) |_| {
        return;
    } else |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    }

    const model_dir = environ.getAlloc(allocator, "ZIGCV_MODEL_DIR") catch |err| switch (err) {
        error.EnvironmentVariableMissing => return error.FileNotFound,
        else => return err,
    };
    defer allocator.free(model_dir);

    const src_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ model_dir, filename });
    defer allocator.free(src_path);

    try cwd.copyFile(src_path, cwd, dest_rel, io, .{});
}

pub fn downloadFile(io: std.Io, url: []const u8, dir: []const u8, allocator: std.mem.Allocator) !void {
    if (dir[dir.len - 1] != '/') unreachable;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    var split_url = std.mem.splitScalar(u8, url, '/');
    var filename: []const u8 = undefined;
    while (split_url.next()) |s| {
        filename = s;
    }
    const dir_filename = try std.fmt.allocPrint(
        arena_allocator,
        "{s}{s}",
        .{ dir, filename },
    );

    ensureFileExists(io, dir_filename, false) catch |err| switch (err) {
        error.FileNotFound, error.FileEmpty => {
            var child = try std.process.spawn(io, .{
                .argv = &.{
                    "curl",
                    url,
                    "-Lo",
                    dir_filename,
                    "--create-dirs",
                },
            });
            _ = try child.wait(io);
            return;
        },
        else => return err,
    };
}

test "ensureNotNull" {
    const ptr: ?*u8 = null;
    try std.testing.expectError(error.AllocationError, ensurePtrNotNull(ptr));
}
