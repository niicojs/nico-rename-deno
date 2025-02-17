const std = @import("std");
const zcsv = @import("zcsv");
const utils = @import("./utils.zig");

const RENAME_FILE = "rename.csv";

pub fn main() !void {
    const cp_out = utils.UTF8ConsoleOutput.init();
    defer cp_out.deinit();

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    defer bw.flush() catch unreachable;

    try stdout.print("┌──────────────┐\n", .{});
    try stdout.print("│ nico renamer │\n", .{});
    try stdout.print("└──────────────┘\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const dirname = if (args.len > 1) args[1] else ".";
    try stdout.print("Répertoire: {s}\n", .{dirname});

    const dir = std.fs.cwd().openDir(dirname, .{ .iterate = true }) catch |err| {
        try stdout.print("Impossible d'ouvrir le répertoire: {s}\n", .{@errorName(err)});
        return;
    };

    const file = dir.openFile(RENAME_FILE, .{}) catch |err| switch (err) {
        std.fs.File.OpenError.FileNotFound => {
            try stdout.print("Génération du fichier CSV...\n", .{});
            try buildExcelFile(dir);
            try stdout.print("Done 🚀\n", .{});
            return;
        },
        else => {
            try stdout.print("Impossible d'ouvrir le fichier CSV: {s}\n", .{@errorName(err)});
            return;
        },
    };

    defer file.close();
    try stdout.print("Renommage...\n", .{});

    var parser = try zcsv.allocs.map.init(allocator, file.reader(), .{ .column_delim = ';' });
    defer parser.deinit();

    while (parser.next()) |row| {
        defer row.deinit();

        const f_fichier = row.data().get("fichier") orelse continue;
        const f_prev = row.data().get("concentration") orelse continue;
        const f_maj = row.data().get("maj") orelse continue;

        const fichier = zcsv.decode.fieldToStr(f_fichier) orelse continue;
        const prev = zcsv.decode.fieldToStr(f_prev) orelse continue;
        const maj = zcsv.decode.fieldToStr(f_maj) orelse continue;

        const newname = get_new_name(allocator, fichier.str, prev.str, maj.str) catch |err| {
            try stdout.print("erreur pour calculer le nouveau nom: {s}\n", .{@errorName(err)});
            continue;
        };

        if (!std.mem.eql(u8, fichier.str, newname)) {
            std.fs.rename(dir, fichier.str, dir, newname) catch |err| {
                try stdout.print("impossible de renommer le fichier '{s}': {s}\n", .{ fichier.str, @errorName(err) });
            };
        }

        defer allocator.free(newname);
    }

    try stdout.print("Done 🚀\n", .{});
}

fn buildExcelFile(dir: std.fs.Dir) !void {
    const file = try dir.createFile(RENAME_FILE, .{ .exclusive = true });
    defer file.close();

    const csv_writer = zcsv.writer.init(file.writer(), .{ .column_delim = ';' });
    try csv_writer.writeRow(.{ "fichier", "concentration", "maj" });

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;
        if (entry.name[0] != '[') continue;
        if (!std.mem.endsWith(u8, entry.name, ".txt")) continue;

        const name = entry.name;
        var i: usize = 1;
        while (std.ascii.isDigit(name[i]) or name[i] == '.' or name[i] == ',') {
            i += 1;
        }

        try csv_writer.writeRow(.{ entry.name, entry.name[1..i], entry.name[1..i] });
    }
}

fn get_new_name(allocator: std.mem.Allocator, name: []const u8, old: []const u8, new: []const u8) ![]const u8 {
    var i: usize = 1;
    while (std.ascii.isDigit(name[i]) or name[i] == '.' or name[i] == ',') {
        i += 1;
    }

    if (!std.mem.eql(u8, old, name[1..i])) {
        return std.mem.Allocator.dupe(allocator, u8, name);
    } else {
        return std.fmt.allocPrint(allocator, "[{s}{s}", .{ new, name[i..] });
    }
}
