const std = @import("std");
const rl = @import("raylib");

pub const StoreError = error{
    ItemNotFound,
};

pub fn Store(comptime T: type) type {
    return struct {
        items: std.StringHashMap(T),

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .items = std.StringHashMap(T).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.items.deinit();
        }

        pub fn set(self: *Self, key: []const u8, value: T) !*const T {
            try self.items.put(key, value);
            return try self.get(key);
        }

        pub fn get(self: *const Self, key: []const u8) StoreError!*const T {
            if (self.items.getPtr(key)) |item| {
                return item;
            } else {
                return StoreError.ItemNotFound;
            }
        }
    };
}

pub const TextureStore = struct {
    store: Store(rl.Texture),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .store = Store(rl.Texture).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.store.deinit();
    }

    pub fn unloadAll(self: *Self) void {
        var it = self.store.items.valueIterator();
        while (it.next()) |item| {
            rl.unloadTexture(item.*);
        }
    }

    pub fn load(self: *Self, key: []const u8, filePath: [:0]const u8) !*const rl.Texture {
        return self.store.set(key, rl.loadTexture(filePath));
    }

    pub fn get(self: *const Self, key: []const u8) !*const rl.Texture {
        return self.store.get(key);
    }
};
