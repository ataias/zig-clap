pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const clap_mod = b.addModule("clap", .{
        .root_source_file = b.path("clap.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run all tests in all modes.");
    const tests = b.addTest(.{ .root_module = clap_mod });
    const run_tests = b.addRunArtifact(tests);
    test_step.dependOn(&run_tests.step);

    const example_step = b.step("examples", "Build examples");
    const example_names = [_][]const u8{
        "complete-demo",
        "help",
        "simple",
        "simple-ex",
        "streaming-clap",
        "subcommands",
        "subcommands-manual",
        "usage",
    };
    var complete_demo: ?*std.Build.Step.Compile = null;
    for (example_names) |example_name| {
        const example = b.addExecutable(.{
            .name = example_name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(b.fmt("example/{s}.zig", .{example_name})),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "clap", .module = clap_mod },
                },
            }),
        });
        const install_example = b.addInstallArtifact(example, .{});
        example_step.dependOn(&example.step);
        example_step.dependOn(&install_example.step);
        if (std.mem.eql(u8, example_name, "complete-demo")) {
            complete_demo = example;
        }
    }

    const docs_step = b.step("docs", "Generate docs.");
    const install_docs = b.addInstallDirectory(.{
        .source_dir = tests.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    docs_step.dependOn(&install_docs.step);

    const test_completions_step = b.step("test-completions", "Run shell completion integration tests");
    const demo = complete_demo orelse @panic("'complete-demo' example must be in the example_names list");
    const fish_test = b.addSystemCommand(&.{
        "fish",
    });
    fish_test.addFileArg(b.path("tests/completions/test_fish.sh"));
    fish_test.addArtifactArg(demo);
    test_completions_step.dependOn(&fish_test.step);

    const all_step = b.step("all", "Build everything and runs all tests");
    all_step.dependOn(test_step);
    all_step.dependOn(example_step);

    b.default_step.dependOn(all_step);
}

const std = @import("std");
