pub const TestMessage = struct {
    x: f32,
    y: i32,
    z: u64,
};

pub const TestContractEnum = enum(u8) {
    testMessage,
};

pub const TestContract = union(TestContractEnum) {
    testMessage: TestMessage,
};
