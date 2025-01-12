pub const MAX_MESSAGE_LENGTH = 1000;

pub const MessageFormatError = error{
    MessageToLong,
    ListTooLong,
};
