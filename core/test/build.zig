const std = @import("std");

pub fn build(b: *std.Build) void {
    const Feature = std.Target.riscv.Feature;
    const enabled_features = std.Target.riscv.featureSet(&[_]Feature{
        .a,
        .m,
        .c,
    });
    const disabled_features = std.Target.riscv.featureSet(&[_]Feature{
        .d,
        .e,
        .f,
    });
    // RV64IMAC
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .riscv64,
        .os_tag = .freestanding,
        .abi = .none,
        .ofmt = .elf,
        .cpu_features_add = enabled_features,
        .cpu_features_sub = disabled_features,
    });
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseSmall,
    });

    const hello = b.addExecutable(.{
        .name = "hello.elf",
        .root_module = b.addModule("hello", .{
            .root_source_file = b.path("zig/hello.zig"),
            .target = target,
            .optimize = optimize,
            .code_model = .medium,
        }),
    });
    hello.entry = .{ .symbol_name = "_start" };
    hello.setLinkerScript(b.path("link.ld"));
    hello.addAssemblyFile(b.path("entry.S"));
    b.installArtifact(hello);

    const hello_step = b.step("hello", "Build hello example");
    hello_step.dependOn(&hello.step);
}
