extern def GetModuleHandleA(lpModuleName: *void) -> *void
extern def RegisterClassA(lpWndClass: *void) -> u16
extern def CreateWindowExA(dwExStyle: u32, lpClassName: *void, lpWindowName: *void, dwStyle: u32, x: int, y: int, nWidth: int, nHeight: int, hWndParent: *void, hMenu: *void, hInstance: *void, lpParam: *void) -> *void
extern def ShowWindow(hWnd: *void, nCmdShow: int) -> int
extern def GetMessageA(lpMsg: *void, hWnd: *void, wMsgFilterMin: u32, wMsgFilterMax: u32) -> int
extern def TranslateMessage(lpMsg: *void) -> int
extern def DispatchMessageA(lpMsg: *void) -> int
extern def PostQuitMessage(nExitCode: int) -> void
extern def DefWindowProcA(hWnd: *void, msg: u32, wParam: i64, lParam: i64) -> i64
extern def BeginPaint(hwnd: *void, lpPaint: *void) -> *void
extern def EndPaint(hwnd: *void, lpPaint: *void) -> int
extern def TextOutA(hdc: *void, x: int, y: int, lpString: *void, c: int) -> int

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

struct PAINTSTRUCT:
    hdc: *void
    fErase: int
    rcPaint_left: int
    rcPaint_top: int
    rcPaint_right: int
    rcPaint_bottom: int
    fRestore: int
    fIncUpdate: int
    pad1: i64
    pad2: i64
    pad3: i64
    pad4: i64

def WindowProc(hWnd: *void, msg: u32, wParam: i64, lParam: i64) -> i64:
    if msg == 15:
        ps: PAINTSTRUCT = {0}
        let hdc = BeginPaint(hWnd, &ps)
        let text = "So it's works"
        
        TextOutA(hdc, 50, 50, text.data, text.length)
        EndPaint(hWnd, &ps)
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
    wc.hbrBackground = 6 as *void
    wc.lpszMenuName = 0 as *void
    wc.lpszClassName = "CBlerrText".data
    
    RegisterClassA(&wc)
    let hWnd = CreateWindowExA(0, "CBlerrText".data, "Ye".data, 13565952, 100, 100, 600, 400, 0 as *void, 0 as *void, hInstance, 0 as *void)
    
    ShowWindow(hWnd, 5)
    
    m: MSG = {0}
    while GetMessageA(&m, 0 as *void, 0, 0) > 0:
        TranslateMessage(&m)
        DispatchMessageA(&m)
        
    endofcode