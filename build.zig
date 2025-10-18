const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    const optimize = .ReleaseSmall;

    // Step 1: Generate LLVM bitcode using zig build-lib
    // Change this to counter.zig for the full-featured example
    const bitcode_path = "entrypoint.bc";
    const gen_bitcode = b.addSystemCommand(&.{
        "zig", "build-lib",
        "-target", "bpfel-freestanding",
        "-O", "ReleaseSmall",
        "-femit-llvm-bc=" ++ bitcode_path,
        "-fno-emit-bin",
        "-Mroot=hello.zig",
    });

    // Step 2: Link with sbpf-linker
    const program_so_path = "zig-out/lib/program_name.so";
    const link_program = b.addSystemCommand(&.{
        "../sbpf-linker/target/debug/sbpf-linker",
        "--cpu", "v3",
        "--export", "entrypoint",
        "-o", program_so_path,
        bitcode_path,
    });
    link_program.step.dependOn(&gen_bitcode.step);

    // Default install step depends on linking
    b.getInstallStep().dependOn(&link_program.step);

    // Optional unit tests (run on host, not BPF)
    const test_step = b.step("test", "Run unit tests");
    const test_module = b.createModule(.{
        .root_source_file = b.path("hello.zig"),
        .target = b.graph.host,
        .optimize = optimize,
    });
    const lib_unit_tests = b.addTest(.{
        .root_module = test_module,
    });
    const run_unit_tests = b.addRunArtifact(lib_unit_tests);
    test_step.dependOn(&run_unit_tests.step);
}
