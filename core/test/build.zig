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

    addTest(b, .{
        .name = "hello",
        .root_source = "zig/hello.zig",
        .entry_asm = "entry.S",
        .linker = "link.ld",
    }, target, optimize);

    addTest(b, .{
        .name = "mswi",
        .root_source = "zig/mswi.zig",
        .entry_asm = "entry.S",
        .linker = "link.ld",
    }, target, optimize);
}

const TestSpec = struct {
    name: []const u8,
    root_source: []const u8,
    entry_asm: []const u8,
    linker: []const u8,
    bytes_per_line: usize = 4,
};

fn addTest(
    b: *std.Build,
    spec: TestSpec,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    // --- ELF ---
    const exe = b.addExecutable(.{
        .name = b.fmt("{s}.elf", .{spec.name}),
        .root_module = b.addModule(spec.name, .{
            .root_source_file = b.path(spec.root_source),
            .target = target,
            .optimize = optimize,
            .code_model = .medium,
        }),
    });
    exe.entry = .{ .symbol_name = "_start" };
    exe.setLinkerScript(b.path(spec.linker));
    exe.addAssemblyFile(b.path(spec.entry_asm));
    b.installArtifact(exe);

    // --- ELF->BIN ---
    const elf = exe.getEmittedBin();
    const bin = elf2bin(b, elf, b.fmt("{s}.bin", .{spec.name}));

    // --- BIN->HEX ---
    const hex = bin2hex(b, bin, .{
        .bytes_per_line = spec.bytes_per_line,
        .basename = b.fmt("{s}.bin.hex", .{spec.name}),
    });

    // install
    b.getInstallStep().dependOn(&b.addInstallFile(bin, b.fmt("{s}.bin", .{spec.name})).step);
    b.getInstallStep().dependOn(&b.addInstallFile(hex, b.fmt("{s}.bin.hex", .{spec.name})).step);
}

fn elf2bin(b: *std.Build, elf: std.Build.LazyPath, out_basename: []const u8) std.Build.LazyPath {
    const oc = b.addObjCopy(elf, .{
        .basename = out_basename,
        .format = .bin,
    });
    return oc.getOutput();
}

fn bin2hex(
    b: *std.Build,
    bin: std.Build.LazyPath,
    options: struct {
        bytes_per_line: usize = 8,
        basename: []const u8,
    },
) std.Build.LazyPath {
    const step = Bin2HexStep.create(b, bin, options.bytes_per_line, options.basename);
    return step.getOutput();
}

const Bin2HexStep = struct {
    step: std.Build.Step,
    input: std.Build.LazyPath,
    bytes_per_line: usize,
    basename: []const u8,
    output_file: std.Build.GeneratedFile,

    pub fn create(owner: *std.Build, input: std.Build.LazyPath, bytes_per_line: usize, basename: []const u8) *@This() {
        const self = owner.allocator.create(@This()) catch @panic("OOM");
        self.* = .{
            .step = std.Build.Step.init(.{
                .id = .custom,
                .name = owner.fmt("bin2hex {s}", .{input.getDisplayName()}),
                .owner = owner,
                .makeFn = make,
            }),
            .input = input,
            .bytes_per_line = bytes_per_line,
            .basename = basename,
            .output_file = .{ .step = &self.step },
        };
        input.addStepDependencies(&self.step);
        return self;
    }

    pub fn getOutput(self: *const @This()) std.Build.LazyPath {
        return .{
            .generated = .{ .file = &self.output_file },
        };
    }

    fn make(step: *std.Build.Step, _: std.Build.Step.MakeOptions) anyerror!void {
        const self: *@This() = @fieldParentPtr("step", step);
        const b = step.owner;

        var man = step.owner.graph.cache.obtain();
        defer man.deinit();

        man.hash.add(@as(u32, 0x6c3a_19d1));
        man.hash.add(self.bytes_per_line);

        const in_path = self.input.getPath(b);
        _ = try man.addFile(in_path, null);

        if (try step.cacheHitAndWatch(&man)) {
            const digest = man.final();
            self.output_file.path = try b.cache_root.join(b.allocator, &.{ "o", &digest, self.basename });
            return;
        }

        const digest = man.final();
        self.output_file.path = try b.cache_root.join(b.allocator, &.{ "o", &digest, self.basename });

        const cache_dir = b.pathJoin(&.{ "o", &digest });
        b.cache_root.handle.makePath(cache_dir) catch |err| {
            return step.fail("unable to make path '{s}': {s}", .{ cache_dir, @errorName(err) });
        };

        var in_file = if (std.fs.path.isAbsolute(in_path))
            try std.fs.openFileAbsolute(in_path, .{})
        else
            try b.build_root.handle.openFile(in_path, .{});
        defer in_file.close();

        const in_bytes = try in_file.readToEndAlloc(b.allocator, std.math.maxInt(usize));
        defer b.allocator.free(in_bytes);

        const rem = in_bytes.len % self.bytes_per_line;
        const pad = self.bytes_per_line - rem; // rem==0 のとき pad==bytes_per_line
        const padded_len = in_bytes.len + pad;

        const out_rel = b.pathJoin(&.{ "o", &digest, self.basename });
        var out_file = try b.cache_root.handle.createFile(out_rel, .{ .truncate = true });
        defer out_file.close();

        var buffer: [4096]u8 = undefined;
        var writer = out_file.writer(&buffer);

        const w = &writer.interface;

        var i: usize = 0;
        while (i < padded_len) : (i += self.bytes_per_line) {
            var j: usize = 0;
            while (j < self.bytes_per_line) : (j += 1) {
                const idx = i + (self.bytes_per_line - 1 - j);
                const byte: u8 = if (idx < in_bytes.len) in_bytes[idx] else 0;
                try w.print("{x:0>2}", .{byte});
            }
            if (i + self.bytes_per_line < padded_len) try w.writeByte('\n');
        }
        try w.flush();

        try step.writeManifestAndWatch(&man);
    }
};
