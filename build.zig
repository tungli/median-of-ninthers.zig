const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const source_file = b.path("src/root.zig");

    const module = b.addModule("median-of-ninthers", .{
        .root_source_file = source_file,
        .optimize = optimize,
        .target = target,
    });

    const tests = b.addTest(.{
        .root_source_file = source_file,
        .optimize = optimize,
        .target = target,
    });

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    const static_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "median_ninthers",
        .root_module = module,
    });
    static_lib.linkLibC();
    b.installArtifact(static_lib);

    const shared_lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "median_ninthers",
        .root_module = module,
    });
    shared_lib.linkLibC();
    b.installArtifact(shared_lib);
}
