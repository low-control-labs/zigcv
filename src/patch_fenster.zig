//! Build tool: adds the pieces zigcv needs to the pinned upstream fenster.h.
//!   - X11: WM_DELETE_WINDOW, so closing the window makes fenster_loop return -1
//!     instead of killing the connection (XIO fatal error)
//!   - keyq/keyq_len key press queue on X11/Win32/Cocoa
//!   - fenster_set_title on X11/Win32/Cocoa
//! Every patch is an insertion after text that must occur exactly once, so a
//! changed upstream fails the build instead of silently producing a wrong header.
//! usage: patch_fenster <fenster.h> <out.h>
const std = @import("std");

const Patch = struct {
    find: []const u8,
    replace: []const u8,
};

fn after(comptime find: []const u8, comptime add: []const u8) Patch {
    return .{ .find = find, .replace = find ++ add };
}

const patches = [_]Patch{
    // struct fenster: key press queue
    after(
        "  int mouse;\n",
        \\  /* Key presses since the caller last drained it (keys[] only holds the
        \\     current state, so a press+release within one loop would be lost).
        \\     The caller resets keyq_len after reading; extra presses are dropped. */
        \\  int keyq[32];
        \\  int keyq_len;
        \\
    ),
    // struct fenster: X11 close atom
    after(
        "  XImage *img;\n",
        "  Atom wm_delete;\n",
    ),
    // API declaration
    after(
        "FENSTER_API void fenster_close(struct fenster *f);\n",
        \\/* Changes the title of an open window; `title` may be freed afterwards. */
        \\FENSTER_API void fenster_set_title(struct fenster *f, const char *title);
        \\
    ),
    // key queue helper
    after(
        "#ifndef FENSTER_HEADER\n",
        \\static void fenster_push_key(struct fenster *f, int k) {
        \\  if (k > 0 && f->keyq_len < (int)(sizeof(f->keyq) / sizeof(f->keyq[0])))
        \\    f->keyq[f->keyq_len++] = k;
        \\}
        \\
        \\
    ),
    // Cocoa: set_title
    after(
        "  msg(void, f->wnd, \"close\");\n}\n\n",
        \\FENSTER_API void fenster_set_title(struct fenster *f, const char *title) {
        \\  id t = msg1(id, cls("NSString"), "stringWithUTF8String:", const char *, title);
        \\  msg1(void, f->wnd, "setTitle:", id, t);
        \\}
        \\
        \\
    ),
    // Cocoa: key queue
    after(
        "    f->keys[k < 127 ? FENSTER_KEYCODES[k] : 0] = evtype == 10;\n",
        \\    if (evtype == 10 && k < 127)
        \\      fenster_push_key(f, FENSTER_KEYCODES[k]);
        \\
    ),
    // Win32: key queue
    after(
        "    f->keys[FENSTER_KEYCODES[HIWORD(lParam) & 0x1ff]] = !((lParam >> 31) & 1);\n",
        \\    if (msg == WM_KEYDOWN)
        \\      fenster_push_key(f, FENSTER_KEYCODES[HIWORD(lParam) & 0x1ff]);
        \\
    ),
    // Win32: set_title
    after(
        "FENSTER_API void fenster_close(struct fenster *f) { (void)f; }\n\n",
        \\FENSTER_API void fenster_set_title(struct fenster *f, const char *title) {
        \\  SetWindowTextA(f->hwnd, title);
        \\}
        \\
        \\
    ),
    // X11: WM_DELETE_WINDOW setup
    after(
        "  XStoreName(f->dpy, f->w, f->title);\n",
        \\  /* Ask the WM for a ClientMessage on close instead of killing the connection. */
        \\  f->wm_delete = XInternAtom(f->dpy, "WM_DELETE_WINDOW", False);
        \\  XSetWMProtocols(f->dpy, f->w, &f->wm_delete, 1);
        \\
    ),
    // X11: set_title
    after(
        "FENSTER_API void fenster_close(struct fenster *f) { XCloseDisplay(f->dpy); }\n",
        \\FENSTER_API void fenster_set_title(struct fenster *f, const char *title) {
        \\  XStoreName(f->dpy, f->w, title);
        \\  XFlush(f->dpy);
        \\}
        \\
    ),
    // X11: close message
    after(
        "    switch (ev.type) {\n",
        \\    case ClientMessage:
        \\      if ((Atom)ev.xclient.data.l[0] == f->wm_delete)
        \\        return -1;
        \\      break;
        \\
    ),
    // X11: key queue
    after(
        "          f->keys[FENSTER_KEYCODES[i + 1]] = (ev.type == KeyPress);\n",
        \\          if (ev.type == KeyPress)
        \\            fenster_push_key(f, FENSTER_KEYCODES[i + 1]);
        \\
    ),
};

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) {
        std.log.err("usage: {s} <fenster.h> <out.h>", .{args[0]});
        std.process.exit(1);
    }

    const dir = std.Io.Dir.cwd();
    var src = try dir.readFileAlloc(init.io, args[1], gpa, .unlimited);
    defer gpa.free(src);
    for (patches) |p| {
        const n = std.mem.count(u8, src, p.find);
        if (n != 1) {
            std.log.err("expected exactly one match, found {d} for:\n{s}", .{ n, p.find });
            std.process.exit(1);
        }
        const next = try std.mem.replaceOwned(u8, gpa, src, p.find, p.replace);
        gpa.free(src);
        src = next;
    }
    try dir.writeFile(init.io, .{ .sub_path = args[2], .data = src });
}
