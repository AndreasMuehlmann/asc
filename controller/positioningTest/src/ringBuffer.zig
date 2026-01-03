const std = @import("std");

pub fn RingBuffer(comptime T: type) type {
    return struct {
        const Self = @This();

        start: usize,
        len: usize,
        capacity: usize,
        buffer: []T,

        pub fn init(allocator: std.mem.Allocator, capacity: usize) !Self {
            return .{
                .start = 0,
                .len = 0,
                .capacity = capacity,
                .buffer = try allocator.alloc(T, capacity),
            }; 
        }
        
        pub fn append(self: *Self, element: T) void {
            if (self.len >= self.capacity) {
                self.buffer[self.start] = element;
                self.start = (self.start + 1) % self.capacity;
                return;
            }
            self.buffer[(self.start + self.len) % self.capacity] = element;
            self.len += 1;
        }

        pub fn get(self: *Self, index: usize) T {
            if (index >= self.len) {
                @panic("Index out of bounds");
            }
            return self.buffer[(self.start + index) % self.capacity];
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.buffer);
        }
    };
}
