pub const MAX_MESSAGE_LENGTH = 1000;
pub const TERMINATION_BYTE = 0xAA;

pub const MessageFormatError = error{
    MessageToLong,
    ListTooLong,
    WrongTerminationByte,
};
