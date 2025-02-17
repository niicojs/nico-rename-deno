const std = @import("std");
const builtin = @import("builtin");
const xlsxwriter = @import("xlsxwriter");

// To make unicode works on windows
pub const UTF8ConsoleOutput = struct {
    original: if (builtin.os.tag == .windows) c_uint else void,

    pub fn init() UTF8ConsoleOutput {
        if (builtin.os.tag == .windows) {
            const original = std.os.windows.kernel32.GetConsoleOutputCP();
            _ = std.os.windows.kernel32.SetConsoleOutputCP(65001);
            return .{ .original = original };
        }
        return .{ .original = {} };
    }

    pub fn deinit(self: UTF8ConsoleOutput) void {
        if (builtin.os.tag == .windows) {
            _ = std.os.windows.kernel32.SetConsoleOutputCP(self.original);
        }
    }
};

pub fn readExcel() !void {
    
}