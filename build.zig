const std = @import("std");

const c_build_options: []const []const u8 = &.{
    "-Wall",
    "-Wextra",
    "--std=c++11",
};

const zig_src_dir = "src/";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const gocv_dep = b.dependency("gocv", .{});
    const fenster_dep = b.dependency("fenster", .{});
    // Upstream fenster.h plus the close handling, key queue and set_title zigcv needs.
    const fenster_patcher = b.addExecutable(.{
        .name = "patch_fenster",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/patch_fenster.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
        }),
    });
    const fenster_patch = b.addRunArtifact(fenster_patcher);
    fenster_patch.addFileArg(fenster_dep.path("fenster.h"));
    const fenster_h = fenster_patch.addOutputFileArg("fenster.h");
    const gocv_src_dir = gocv_dep.path("");
    const gocv_contrib_dir = gocv_dep.path("contrib");
    // Upstream core.h/core.cpp/dnn.cpp/objdetect.cpp plus Mats_New and the string ownership fixes zigcv needs.
    const gocv_patcher = b.addExecutable(.{
        .name = "patch_gocv",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/patch_gocv.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
        }),
    });
    const gocv_patch = b.addRunArtifact(gocv_patcher);
    gocv_patch.addDirectoryArg(gocv_src_dir);
    const gocv_patched_dir = gocv_patch.addOutputDirectoryArg("gocv_patched");
    // Used by the face detection examples.
    b.addNamedLazyPath("haarcascade_frontalface_default", gocv_dep.path("data/haarcascade_frontalface_default.xml"));

    const opencv = buildOpenCV(b, target);
    const opencv_libs = opencv.install;
    const opencv4_headers_dir = opencv.prefix.path(b, "include/opencv4");

    // Static, like OpenCV: binaries end up self-contained, nothing loads from .zig-cache.
    const zigcv_lib = b.addLibrary(.{
        .name = "zigcv",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        }),
    });
    zigcv_lib.step.dependOn(&opencv_libs.step);

    const lib_mod = zigcv_lib.root_module;
    lib_mod.addIncludePath(gocv_patched_dir); // Patched gocv sources, ahead of the originals
    lib_mod.addIncludePath(gocv_src_dir); // OpenCV C bindings base
    lib_mod.addIncludePath(gocv_contrib_dir); // OpenCV contrib C bindings
    lib_mod.addIncludePath(b.path(zig_src_dir)); // Our glue header
    lib_mod.addIncludePath(opencv4_headers_dir); // Include the opencv4 headers

    lib_mod.addCSourceFiles(.{
        .files = &.{
            "core.cpp",
            "dnn.cpp",
            "objdetect.cpp",
        },
        .root = gocv_patched_dir,
        .flags = c_build_options,
    });

    lib_mod.addCSourceFiles(.{
        .files = &.{
            "aruco.cpp",
            "asyncarray.cpp",
            "calib3d.cpp",
            "features2d.cpp",
            "highgui.cpp",
            "imgcodecs.cpp",
            "imgproc.cpp",
            "persistence_filenode.cpp",
            "persistence_filestorage.cpp",
            "photo.cpp",
            "svd.cpp",
            "version.cpp",
            "video.cpp",
            "videoio.cpp",
        },
        .root = gocv_src_dir,
        .flags = c_build_options,
    });

    lib_mod.addCSourceFiles(.{
        .files = &.{
            "bgsegm.cpp",
            "face.cpp",
            // freetype.cpp needs system freetype + harfbuzz; excluded from the hermetic build.
            "img_hash.cpp",
            "tracking.cpp",
            "wechat_qrcode.cpp",
            "xfeatures2d.cpp",
            "ximgproc.cpp",
            "xphoto.cpp",
        },
        .root = gocv_contrib_dir,
        .flags = c_build_options,
    });

    // fenster: single-header window/framebuffer (the header is also the implementation).
    lib_mod.addCSourceFile(.{ .file = fenster_h, .language = .c });

    b.installArtifact(zigcv_lib);

    // ---- C bindings ---------------------------------------------------------
    // @cImport was removed; translate the gocv headers through the build system.
    const c_api_h = b.addWriteFiles().add("c_api.h", c_api_includes);
    const translate_c = b.addTranslateC(.{
        .root_source_file = c_api_h,
        .target = target,
        .optimize = optimize,
    });
    translate_c.step.dependOn(&opencv_libs.step);
    translate_c.addIncludePath(gocv_patched_dir);
    translate_c.addIncludePath(gocv_src_dir);
    translate_c.addIncludePath(gocv_contrib_dir);
    translate_c.addIncludePath(b.path(zig_src_dir));
    translate_c.addIncludePath(opencv4_headers_dir);
    const c_mod = translate_c.createModule();

    // Separate module so X11 names (Window, Display, ...) don't mix into `c`.
    const translate_fenster = b.addTranslateC(.{
        .root_source_file = fenster_h,
        .target = target,
        .optimize = optimize,
    });
    translate_fenster.defineCMacro("FENSTER_HEADER", null);
    const fenster_mod = translate_fenster.createModule();

    // ---- Zig module ---------------------------------------------------------
    const zigcv = b.addModule("root", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
        .imports = &.{
            .{ .name = "c", .module = c_mod },
            .{ .name = "fenster", .module = fenster_mod },
        },
    });
    // Link inputs live on the module so every artifact importing it (examples, tests,
    // downstream packages) gets the full static link line. zigcv first, then OpenCV
    // from high-level modules down to core, then its 3rdparty libs, TBB and OpenBLAS.
    zigcv.linkLibrary(zigcv_lib);
    for (opencv_modules) |name| zigcv.addObjectFile(opencv.prefix.path(b, b.fmt("lib/lib{s}.a", .{name})));
    for (opencv_3rdparty_libs) |name| zigcv.addObjectFile(opencv.prefix.path(b, b.fmt("lib/opencv4/3rdparty/lib{s}.a", .{name})));
    zigcv.addObjectFile(opencv.tbb_prefix.path(b, "lib/libtbb.a"));
    zigcv.addObjectFile(opencv.openblas_prefix.path(b, "lib/libopenblas.a"));
    switch (target.result.os.tag) {
        .macos => zigcv.linkFramework("Cocoa", .{}),
        .windows => zigcv.linkSystemLibrary("gdi32", .{}),
        else => {
            zigcv.linkSystemLibrary("X11", .{});
            zigcv.linkSystemLibrary("dl", .{});
            zigcv.linkSystemLibrary("pthread", .{});
        },
    }

    // ---- Unit tests ---------------------------------------------------------
    const unit_tests = b.addTest(.{ .root_module = zigcv });
    b.installArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&b.addRunArtifact(unit_tests).step);

    // ---- Examples -----------------------------------------------------------
    // `zig build examples` builds all; `zig build <name> -- args` runs one.
    const examples_step = b.step("examples", "Builds all the examples");

    // Cascade for face_detection / face_blur; they default to this installed path.
    const haarcascade = b.addInstallFile(
        gocv_dep.path("data/haarcascade_frontalface_default.xml"),
        "share/haarcascade_frontalface_default.xml",
    );
    examples_step.dependOn(&haarcascade.step);

    for (examples) |ex| {
        const exe = b.addExecutable(.{
            .name = ex.name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(ex.path),
                .target = target,
                .optimize = optimize,
                .imports = &.{.{ .name = "zigcv", .module = zigcv }},
            }),
        });
        const install_exe = b.addInstallArtifact(exe, .{});
        examples_step.dependOn(&install_exe.step);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.addPassthruArgs();
        run_cmd.step.dependOn(&install_exe.step);
        run_cmd.step.dependOn(&haarcascade.step);
        b.step(ex.name, ex.desc).dependOn(&run_cmd.step);
    }
}

const Example = struct {
    name: []const u8,
    path: []const u8,
    desc: []const u8,
};

const examples = [_]Example{
    .{ .name = "hello", .path = "examples/hello/main.zig", .desc = "Show Webcam" },
    .{ .name = "version", .path = "examples/version/main.zig", .desc = "Print OpenCV Version" },
    .{ .name = "show_image", .path = "examples/showimage/main.zig", .desc = "Show Image Demo" },
    .{ .name = "face_detection", .path = "examples/facedetect/main.zig", .desc = "Face Detection Demo" },
    .{ .name = "face_blur", .path = "examples/faceblur/main.zig", .desc = "Face Detection and Blur Demo" },
    .{ .name = "dnn_detection", .path = "examples/dnndetection/main.zig", .desc = "DNN Detection Demo" },
    .{ .name = "saveimage", .path = "examples/saveimage/main.zig", .desc = "Save Image Demo" },
    .{ .name = "detail_enhance", .path = "examples/detail_enhance/main.zig", .desc = "Detail Enhanced Image Demo" },
};

const c_api_includes =
    \\#include <stdlib.h>
    \\
    \\// First, so the patched core.h wins over the original (include guard).
    \\#include "core.h"
    \\
    \\#include "asyncarray.h"
    \\#include "aruco.h"
    \\#include "calib3d.h"
    \\#include "core.h"
    \\#include "dnn.h"
    \\#include "features2d.h"
    \\#include "highgui_gocv.h"
    \\#include "imgcodecs.h"
    \\#include "imgproc.h"
    \\#include "objdetect.h"
    \\#include "persistence.h"
    \\#include "photo.h"
    \\#include "svd.h"
    \\#include "version.h"
    \\#include "video.h"
    \\#include "videoio.h"
    \\
    \\#include "bgsegm.h"
    \\#include "face.h"
    \\#include "freetype.h"
    \\#include "img_hash.h"
    \\#include "tracking.h"
    \\#include "wechat_qrcode.h"
    \\#include "xfeatures2d.h"
    \\#include "ximgproc.h"
    \\#include "xphoto.h"
    \\
;

/// The OpenCV modules gocv wraps plus their required deps (plot: tracking, flann: calib3d),
/// in static link order: every module comes before the modules it depends on.
/// Also passed to cmake as BUILD_LIST, so nothing else from main or contrib is built.
const opencv_modules = [_][]const u8{
    // contrib
    "opencv_xfeatures2d",
    "opencv_ximgproc",
    "opencv_xphoto",
    "opencv_tracking",
    "opencv_face",
    "opencv_bgsegm",
    "opencv_img_hash",
    "opencv_wechat_qrcode",
    "opencv_aruco",
    "opencv_plot",
    // main
    "opencv_objdetect",
    "opencv_video",
    "opencv_calib3d",
    "opencv_features2d",
    "opencv_flann",
    "opencv_dnn",
    "opencv_photo",
    "opencv_highgui",
    "opencv_videoio",
    "opencv_imgcodecs",
    "opencv_imgproc",
    "opencv_core",
};

/// OpenCV's bundled 3rdparty libs (BUILD_*=ON), installed to lib/opencv4/3rdparty
/// in a static build. Without gapi there's no ade.
const opencv_3rdparty_libs = [_][]const u8{
    "IlmImf",
    "libprotobuf",
    "libopenjp2",
    "libwebp",
    "libtiff",
    "libjpeg-turbo",
    "libpng",
    "zlib",
};

/// A cmake project built hermetically with the running zig as the C/C++ compiler.
const CMakeProject = struct {
    configure: *std.Build.Step.Run,
    /// The final step; depend on this before using `prefix`.
    install: *std.Build.Step.Run,
    /// CMAKE_INSTALL_PREFIX (only valid once `install` has run).
    prefix: std.Build.LazyPath,

    /// Adds `-D <name>=<dir>`, and orders this configure after `dep` is installed.
    fn addDepDir(self: CMakeProject, name: []const u8, dep: CMakeProject, sub_path: []const u8) void {
        const b = self.configure.step.owner;
        self.configure.addArg("-D");
        self.configure.addDirectoryArg2(dep.prefix.path(b, sub_path), .{ .prefix = b.fmt("{s}=", .{name}), .make_absolute = true });
        self.configure.step.dependOn(&dep.install.step);
    }

    /// Like `addDepDir`, for a file inside `dep`'s install prefix.
    fn addDepFile(self: CMakeProject, name: []const u8, dep: CMakeProject, sub_path: []const u8) void {
        const b = self.configure.step.owner;
        self.configure.addArg("-D");
        self.configure.addFileArg2(dep.prefix.path(b, sub_path), .{ .prefix = b.fmt("{s}=", .{name}), .make_absolute = true });
        self.configure.step.dependOn(&dep.install.step);
    }
};

/// `zig cc` / `zig c++` as single executables for cmake.
const ZigCompilers = struct {
    cc: std.Build.LazyPath,
    cxx: std.Build.LazyPath,
};

/// cmake splits `CC="zig cc -target ..."` into the program and extra args, but some
/// projects use only the program part (OpenBLAS runs `${CMAKE_C_COMPILER}` directly for
/// .S kernels and probes), ending up with plain `zig`. A wrapper exe avoids that.
fn zigCompilerWrappers(b: *std.Build, target: std.Build.ResolvedTarget) ZigCompilers {
    return .{
        .cc = zigCompilerWrapper(b, "zig-cc", "cc", target),
        .cxx = zigCompilerWrapper(b, "zig-c++", "c++", target),
    };
}

fn zigCompilerWrapper(b: *std.Build, name: []const u8, mode: []const u8, target: std.Build.ResolvedTarget) std.Build.LazyPath {
    const t = target.result;
    var args: []const u8 = b.fmt("\"{f}\", \"{s}\", ", .{ std.zig.fmtString(b.graph.zig_exe), mode });
    // On Linux an explicit (non-native) target stops zig from adding /usr/include ahead
    // of the project's -isystem dirs, so bundled 3rdparty headers win over system ones.
    // Elsewhere a native target stays native so zig still finds the system SDK
    // (e.g. macOS frameworks); a cross target is always passed through.
    if (t.os.tag == .linux or !target.query.isNative()) {
        args = b.fmt("{s}\"-target\", \"{t}-{t}-{t}\", ", .{ args, t.cpu.arch, t.os.tag, t.abi });
    }
    // -fno-sanitize=undefined: without an -O flag zig cc defaults to UBSan, which traps
    // in helper programs cmake compiles and runs (e.g. OpenBLAS getarch's `1 << 31`).
    const source = b.fmt(
        \\const std = @import("std");
        \\
        \\const prefix = [_][]const u8{{ {s}"-fno-sanitize=undefined" }};
        \\
        \\pub fn main(init: std.process.Init) !void {{
        \\    const arena = init.arena.allocator();
        \\    const args = try init.minimal.args.toSlice(arena);
        \\    var argv: std.ArrayList([]const u8) = .empty;
        \\    try argv.appendSlice(arena, &prefix);
        \\    for (args[1..]) |arg| try argv.append(arena, arg);
        \\    return std.process.replace(init.io, .{{ .argv = argv.items }});
        \\}}
        \\
    , .{args});

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.addWriteFiles().add(b.fmt("{s}.zig", .{name}), source),
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
        }),
    });
    return exe.getEmittedBin();
}

fn cmakeProject(b: *std.Build, name: []const u8, source: std.Build.LazyPath, compilers: ZigCompilers, target: std.Build.ResolvedTarget, jobs: u32) CMakeProject {
    // -Wno-author/-Wno-deprecated: old CMakeLists spam policy warnings on cmake 4.
    const configure = b.addSystemCommand(&.{ "cmake", "-Wno-author", "-Wno-deprecated", "-B" });
    configure.setName(b.fmt("Configuring {s} (cmake)", .{name}));
    const work_dir = configure.addOutputDirectoryArg("build_work");
    // cmake requires an absolute compiler path.
    configure.addArg("-D");
    configure.addFileArg2(compilers.cc, .{ .prefix = "CMAKE_C_COMPILER=", .make_absolute = true });
    configure.addArg("-D");
    configure.addFileArg2(compilers.cxx, .{ .prefix = "CMAKE_CXX_COMPILER=", .make_absolute = true });
    configure.addArg("-D");
    configure.addFileArg2(compilers.cc, .{ .prefix = "CMAKE_ASM_COMPILER=", .make_absolute = true });
    // Hide system .pc files so pkg-config can't find system libraries.
    configure.setEnvironmentVariable("PKG_CONFIG_LIBDIR", "");
    configure.setEnvironmentVariable("PKG_CONFIG_PATH", "");
    configure.addArg("-D");
    const prefix = configure.addPrefixedOutputDirectoryArg("CMAKE_INSTALL_PREFIX=", "install");
    configure.addArgs(&.{
        "-D",
        "CMAKE_BUILD_TYPE=Release",
        // GNUInstallDirs picks lib or lib64 depending on the distro.
        "-D",
        "CMAKE_INSTALL_LIBDIR=lib",
        // Everything ends up in one link; PIC keeps it usable from shared libs/PIE too.
        "-D",
        "CMAKE_POSITION_INDEPENDENT_CODE=ON",
    });
    if (target.result.os.tag == .linux) {
        // Hermetic: never look at /usr. "/" and "/lib" too: on Arch /lib -> /usr/lib,
        // and cmake finds packages via /lib/cmake. (Linux only: on macOS this would
        // also hide the SDK.)
        configure.addArgs(&.{ "-D", "CMAKE_IGNORE_PREFIX_PATH=/;/lib;/usr;/usr/local" });
    }
    configure.addDirectoryArg(source);
    configure.expectExitCode(0);

    const build_cmd = b.addSystemCommand(&.{ "cmake", "--build" });
    build_cmd.setName(b.fmt("Compiling {s} with zig", .{name}));
    build_cmd.addDirectoryArg(work_dir);
    build_cmd.addArgs(&.{ "--parallel", b.fmt("{d}", .{jobs}) });
    build_cmd.step.dependOn(&configure.step);
    build_cmd.expectExitCode(0);

    const install = b.addSystemCommand(&.{ "cmake", "--install" });
    install.setName(b.fmt("Installing {s}", .{name}));
    install.addDirectoryArg(work_dir);
    install.step.dependOn(&build_cmd.step);
    install.expectExitCode(0);

    return .{ .configure = configure, .install = install, .prefix = prefix };
}

const OpenCV = struct {
    /// Depend on this before using any of the prefixes.
    install: *std.Build.Step.Run,
    prefix: std.Build.LazyPath,
    tbb_prefix: std.Build.LazyPath,
    openblas_prefix: std.Build.LazyPath,
};

fn buildOpenCV(b: *std.Build, target: std.Build.ResolvedTarget) OpenCV {
    const opencv_dep = b.dependency("opencv", .{});
    const opencv_contrib_dep = b.dependency("opencv_contrib", .{});

    // Each OpenCV compile job can take 1-2 GB of RAM; unbounded parallelism freezes the machine.
    const jobs = b.option(u32, "opencv-jobs", "Parallel jobs for the OpenCV build (default 4)") orelse 4;

    const compilers = zigCompilerWrappers(b, target);

    const tbb = cmakeProject(b, "oneTBB", b.dependency("onetbb", .{}).path(""), compilers, target, jobs);
    tbb.configure.addArgs(&.{
        "-D", "BUILD_SHARED_LIBS=OFF",
        "-D", "TBB_TEST=OFF",
        "-D", "TBB_EXAMPLES=OFF",
        // TBB_STRICT turns warnings into errors; newer clang adds warnings it doesn't expect.
        "-D", "TBB_STRICT=OFF",
    });

    const openblas = cmakeProject(b, "OpenBLAS", b.dependency("openblas", .{}).path(""), compilers, target, jobs);
    openblas.configure.addArgs(&.{
        "-D", "BUILD_SHARED_LIBS=OFF",
        "-D", "BUILD_STATIC_LIBS=ON",
        "-D", "BUILD_TESTING=OFF",
        // No Fortran compiler: build LAPACK from its C translation.
        "-D", "NOFORTRAN=ON",
        "-D", "C_LAPACK=ON",
        // ctest/CMakeLists.txt (always added) does `${CMAKE_Fortran_COMPILER_ID} STREQUAL GNU`
        // unquoted; empty without Fortran, which breaks the if(). Any non-empty value works.
        "-D", "CMAKE_Fortran_COMPILER_ID=NONE",
        "-D", "USE_OPENMP=0",
    });

    const opencv = cmakeProject(b, "OpenCV", opencv_dep.path(""), compilers, target, jobs);
    const configure_cmd = opencv.configure;

    // Only the modules gocv wraps (see `opencv_modules`).
    var build_list: []const u8 = "";
    for (opencv_modules, 0..) |m, i| {
        build_list = b.fmt("{s}{s}{s}", .{ build_list, if (i == 0) "" else ",", m["opencv_".len..] });
    }
    configure_cmd.addArgs(&.{
        "-D",
        "BUILD_SHARED_LIBS=OFF",
        "-D",
        b.fmt("BUILD_LIST={s}", .{build_list}),
        "-D",
        "WITH_IPP=OFF",
        "-D",
    });
    configure_cmd.addPrefixedDirectoryArg("OPENCV_EXTRA_MODULES_PATH=", opencv_contrib_dep.path("modules"));

    // TBB: OpenCV's find_package(TBB) picks up TBBConfig.cmake from TBB_DIR.
    opencv.addDepDir("TBB_DIR", tbb, "lib/cmake/TBB");
    // OpenBLAS: pre-set the cache vars OpenCVFindOpenBLAS.cmake would search for.
    opencv.addDepDir("OpenBLAS_INCLUDE_DIR", openblas, "include/openblas");
    opencv.addDepFile("OpenBLAS_LIB", openblas, "lib/libopenblas.a");
    // Eigen: header-only, Eigen/Core sits at the repo root.
    configure_cmd.addArg("-D");
    configure_cmd.addDirectoryArg2(b.dependency("eigen", .{}).path(""), .{ .prefix = "EIGEN_INCLUDE_PATH=", .make_absolute = true });

    configure_cmd.addArgs(&.{
        "-D",
        "WITH_TBB=ON",
        // Static TBB already contains Intel's ittnotify; OpenCV's bundled copy would
        // define the same __itt_* symbols twice. ITT is only for VTune profiling.
        "-D",
        "WITH_ITT=OFF",
        "-D",
        "WITH_EIGEN=ON",
        "-D",
        "WITH_LAPACK=ON",
        "-D",
        "OPENCV_LAPACK_DISABLE_MKL=ON",
        "-D",
        "WITH_OPENEXR=ON",
        "-D",
        "BUILD_OPENEXR=ON",
        "-D",
        "WITH_AVIF=OFF",
        "-D",
        "WITH_JPEGXL=OFF",
        "-D",
        "BUILD_opencv_hdf=OFF",
        "-D",
        "BUILD_ZLIB=ON",
        "-D",
        "BUILD_PNG=ON",
        "-D",
        "BUILD_JPEG=ON",
        "-D",
        "BUILD_TIFF=ON",
        "-D",
        "BUILD_WEBP=ON",
        "-D",
        "BUILD_OPENJPEG=ON",
        "-D",
        "BUILD_PROTOBUF=ON",
        "-D",
        "WITH_FFMPEG=OFF",
        "-D",
        "WITH_GSTREAMER=OFF",
        "-D",
        "WITH_GTK=OFF",
        "-D",
        "WITH_QT=OFF",
        "-D",
        "WITH_1394=OFF",
        "-D",
        "WITH_VTK=OFF",
        "-D",
        "OPENCV_ENABLE_NONFREE=ON",
        "-D",
        "WITH_JASPER=OFF",
        "-D",
        "BUILD_DOCS=OFF",
        "-D",
        "BUILD_EXAMPLES=OFF",
        "-D",
        "BUILD_TESTS=OFF",
        "-D",
        "BUILD_PERF_TESTS=OFF",
        "-D",
        "BUILD_opencv_java=NO",
        "-D",
        "BUILD_opencv_python=NO",
        "-D",
        "BUILD_opencv_python2=NO",
        "-D",
        "BUILD_opencv_python3=NO",
        "-D",
        "OPENCV_GENERATE_PKGCONFIG=OFF",
    });

    return .{
        .install = opencv.install,
        .prefix = opencv.prefix,
        .tbb_prefix = tbb.prefix,
        .openblas_prefix = openblas.prefix,
    };
}
