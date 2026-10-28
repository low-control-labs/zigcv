//! Build tool: patches the pinned upstream gocv sources zigcv needs.
//!   - Mats_New: allocates a Mats of a given length (core.h/core.cpp)
//!   - Net_GetLayerNames: gocv stores c_str() pointers of a local vector of strings,
//!     which CStrings_Close() later deletes; allocate each name with new[] instead
//!   - QRCodeDetector_DetectAndDecodeMulti: same defect for the decoded strings, and
//!     the outputs are left unset when nothing is detected
//! Every patch is an exact text match that must occur exactly once, so a changed
//! upstream fails the build instead of silently producing a wrong source.
//! usage: patch_gocv <gocv_dir> <out_dir>
//! Writes the patched core.h, core.cpp, dnn.cpp and objdetect.cpp into <out_dir>.
const std = @import("std");

const Patch = struct {
    find: []const u8,
    replace: []const u8,
};

const File = struct {
    name: []const u8,
    patches: []const Patch,
};

fn after(comptime find: []const u8, comptime add: []const u8) Patch {
    return .{ .find = find, .replace = find ++ add };
}

fn replace(comptime find: []const u8, comptime with: []const u8) Patch {
    return .{ .find = find, .replace = with };
}

const files = [_]File{
    .{ .name = "core.h", .patches = &.{
        after(
            "Mat Mats_get(struct Mats mats, int i);\n",
            \\struct Mats Mats_New(int length);
            \\
        ),
    } },
    .{ .name = "core.cpp", .patches = &.{
        after(
            "Mat Mats_get(struct Mats mats, int i) {\n    return mats.mats[i];\n}\n\n",
            \\struct Mats Mats_New(int length) {
            \\    struct Mats mats;
            \\    mats.length = length;
            \\    mats.mats = new Mat[length];
            \\    return mats;
            \\}
            \\
            \\
        ),
    } },
    .{ .name = "dnn.cpp", .patches = &.{
        after(
            "#include \"dnn.h\"\n",
            \\#include <cstring>
            \\
        ),
        replace(
            "        strs[i] = cstrs[i].c_str();\n",
            \\        char *s = new char[cstrs[i].size() + 1];
            \\        std::memcpy(s, cstrs[i].c_str(), cstrs[i].size() + 1);
            \\        strs[i] = s;
            \\
        ),
    } },
    .{ .name = "objdetect.cpp", .patches = &.{
        after(
            "#include \"objdetect.h\"\n",
            \\#include <cstring>
            \\
        ),
        after(
            "bool QRCodeDetector_DetectAndDecodeMulti(QRCodeDetector qr, Mat input, CStrings* decoded, Mat points, struct Mats* qrCodes) {\n",
            \\  decoded->strs = nullptr;
            \\  decoded->length = 0;
            \\  qrCodes->mats = nullptr;
            \\  qrCodes->length = 0;
            \\
        ),
        replace(
            "      strs[i] = decodedCodes[i].c_str();\n",
            \\      char *s = new char[decodedCodes[i].size() + 1];
            \\      std::memcpy(s, decodedCodes[i].c_str(), decodedCodes[i].size() + 1);
            \\      strs[i] = s;
            \\
        ),
    } },
};

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) {
        std.log.err("usage: {s} <gocv_dir> <out_dir>", .{args[0]});
        std.process.exit(1);
    }

    const dir = std.Io.Dir.cwd();
    for (files) |file| {
        const in_path = try std.fmt.allocPrint(gpa, "{s}/{s}", .{ args[1], file.name });
        defer gpa.free(in_path);
        const out_path = try std.fmt.allocPrint(gpa, "{s}/{s}", .{ args[2], file.name });
        defer gpa.free(out_path);

        var src = try dir.readFileAlloc(init.io, in_path, gpa, .unlimited);
        defer gpa.free(src);
        for (file.patches) |p| {
            const n = std.mem.count(u8, src, p.find);
            if (n != 1) {
                std.log.err("{s}: expected exactly one match, found {d} for:\n{s}", .{ file.name, n, p.find });
                std.process.exit(1);
            }
            const next = try std.mem.replaceOwned(u8, gpa, src, p.find, p.replace);
            gpa.free(src);
            src = next;
        }
        try dir.writeFile(init.io, .{ .sub_path = out_path, .data = src });
    }
}
