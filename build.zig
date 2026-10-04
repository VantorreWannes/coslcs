const std = @import("std");

const DistTarget = struct {
    query: std.Target.Query,
    output: []const u8,
};

const dist_targets = [_]DistTarget{
    .{ .query = .{ .cpu_arch = .x86_64, .os_tag = .windows }, .output = "coslcs-windows-x86_64.lib" },
    .{ .query = .{ .cpu_arch = .aarch64, .os_tag = .windows }, .output = "coslcs-windows-arm64.lib" },
    .{ .query = .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .musl }, .output = "libcoslcs-linux-x86_64.a" },
    .{ .query = .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .musl }, .output = "libcoslcs-linux-arm64.a" },
    .{ .query = .{ .cpu_arch = .x86_64, .os_tag = .macos }, .output = "libcoslcs-macos-x86_64.a" },
    .{ .query = .{ .cpu_arch = .aarch64, .os_tag = .macos }, .output = "libcoslcs-macos-arm64.a" },
};

pub fn build(b: *std.Build) void {
    // Options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const use_llvm = b.option(bool, "llvm", "Use the LLVM backend");

    // Packages
    const zbench_mod = b.dependency("zbench", .{ .target = target, .optimize = optimize }).module("zbench");

    // Modules
    const coslcs_mod = b.addModule("coslcs", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const bench_mod = b.createModule(.{
        .root_source_file = b.path("src/bench.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "coslcs", .module = coslcs_mod },
            .{ .name = "zbench", .module = zbench_mod },
        },
    });

    // Artifacts
    const coslcs_lib = b.addLibrary(.{
        .name = "coslcs",
        .root_module = coslcs_mod,
        .use_llvm = use_llvm,
    });

    const bench_bin = b.addExecutable(.{
        .name = "benchmarks",
        .root_module = bench_mod,
        .use_llvm = use_llvm,
    });

    const coslcs_tests = b.addTest(.{
        .root_module = coslcs_mod,
        .use_llvm = use_llvm,
    });

    // Steps
    const bench_cmd = b.addRunArtifact(bench_bin);
    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&bench_cmd.step);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&b.addRunArtifact(coslcs_tests).step);

    const docs_dir = b.addInstallDirectory(.{
        .source_dir = coslcs_lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    const docs_step = b.step("docs", "Install docs into zig-out/docs");
    docs_step.dependOn(&docs_dir.step);

    const dist_step = b.step("dist", "Build release libraries for all supported platforms");

    for (dist_targets) |dist| {
        const dist_mod = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = b.resolveTargetQuery(dist.query),
            .optimize = optimize,
            .link_libc = true,
        });

        const dist_lib = b.addLibrary(.{
            .name = "coslcs",
            .root_module = dist_mod,
            .use_llvm = use_llvm,
        });

        dist_step.dependOn(&b.addInstallArtifact(dist_lib, .{ .dest_sub_path = dist.output }).step);
    }

    // Install
    b.installArtifact(coslcs_lib);

    if (b.args) |args| {
        bench_cmd.addArgs(args);
    }
}
