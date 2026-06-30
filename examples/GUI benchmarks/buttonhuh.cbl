extern def GetModuleHandleA(lpModuleName: *void) -> *void
extern def RegisterClassA(lpWndClass: *void) -> u16
extern def CreateWindowExA(dwExStyle: u32, lpClassName: *void, lpWindowName: *void, dwStyle: u32, x: int, y: int, nWidth: int, nHeight: int, hWndParent: *void, hMenu: *void, hInstance: *void, lpParam: *void) -> *void
extern def ShowWindow(hWnd: *void, nCmdShow: int) -> int
extern def GetMessageA(lpMsg: *void, hWnd: *void, wMsgFilterMin: u32, wMsgFilterMax: u32) -> int
extern def TranslateMessage(lpMsg: *void) -> int
extern def DispatchMessageA(lpMsg: *void) -> int
extern def PostQuitMessage(nExitCode: int) -> void
extern def DefWindowProcA(hWnd: *void, msg: u32, wParam: i64, lParam: i64) -> i64
extern def MessageBoxA(hWnd: *void, lpText: *void, lpCaption: *void, uType: u32) -> int

struct WNDCLASSA:
    style: u32
    lpfnWndProc: *void
    cbClsExtra: int
    cbWndExtra: int
    hInstance: *void
    hIcon: *void
    hCursor: *void
    hbrBackground: *void
    lpszMenuName: *void
    lpszClassName: *void

struct MSG:
    hwnd: *void
    message: u32
    wParam: i64
    lParam: i64
    time: u32
    pt_x: int
    pt_y: int

def WindowProc(hWnd: *void, msg: u32, wParam: i64, lParam: i64) -> i64:
    if msg == 273: 
        let wmId = wParam & 65535
        if wmId == 1002:
            MessageBoxA(hWnd, "Button worked\nyay".data, "Works".data, 0)
        endofcode
        
    if msg == 2:
        PostQuitMessage(0)
        endofcode
        
    return DefWindowProcA(hWnd, msg, wParam, lParam)

def main() -> int:
    let hInstance = GetModuleHandleA(0 as *void)
    
    wc: WNDCLASSA = {0}
    wc.style = 3
    wc.lpfnWndProc = WindowProc as *void
    wc.cbClsExtra = 0
    wc.cbWndExtra = 0
    wc.hInstance = hInstance
    wc.hIcon = 0 as *void
    wc.hCursor = 0 as *void
    wc.hbrBackground = 16 as *void
    wc.lpszMenuName = 0 as *void
    wc.lpszClassName = "CBlerrAction".data
    
    RegisterClassA(&wc)
    let hWnd = CreateWindowExA(0, "CBlerrAction".data, "Workable window".data, 13565952, 200, 200, 400, 300, 0 as *void, 0 as *void, hInstance, 0 as *void)
    
    CreateWindowExA(0, "BUTTON".data, "Open dialog".data, 1342177280, 120, 100, 150, 40, hWnd, 1002 as *void, hInstance, 0 as *void)
    
    ShowWindow(hWnd, 5)
    
    m: MSG = {0}
    while GetMessageA(&m, 0 as *void, 0, 0) > 0:
        TranslateMessage(&m)
        DispatchMessageA(&m)
        
    endofcode