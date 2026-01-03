pub fn RingBuffer(comptime T: type, comptime capacity: usize) type {
    return struct {
        var array: [capacity]T = undefined;
        const Self = @This();

        start: usize,
        items: []T,
        capacity: usize,

        pub fn init() Self {
            return .{
                .start = 0,
                .items = array[0..0],
                .capacity = capacity,
            }; 
        }
        
        pub fn append(self: *Self, element: T) void {
            if (self.items.len >= capacity) {
                self.items[self.start] = element;
                self.start = (self.start + 1) % capacity;
                return;
            }
            self.items = array[0..self.items.len + 1];
            self.items[self.items.len - 1] = element;
        }

        pub fn get(self: *Self, index: usize) T {
            if (index >= self.items.len) {
                @panic("Index out of bounds");
            }
            return self.items[(self.start + index) % self.capacity];
        }
    };
}
