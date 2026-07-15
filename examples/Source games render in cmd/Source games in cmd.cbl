struct RECT:
    left: int
    top: int
    right: int
    bottom: int

struct BITMAPINFOHEADER:
    biSize: int
    biWidth: int
    biHeight: int
    biPlanes: i16
    biBitCount: i16
    biCompression: int
    biSizeImage: int
    biXPelsPerMeter: int
    biYPelsPerMeter: int
    biClrUsed: int
    biClrImportant: int

def main() -> int:
    stdout: *void = GetStdHandle(-11)
    written: int = 0
    
    SetConsoleOutputCP(65001) 
    
    mode: int = 0
    GetConsoleMode(stdout, (&mode) as *void)
    mode = mode | 4 
    SetConsoleMode(stdout, mode)
    
    resize_seq: str = "\x1b[8;46;160t" 
    WriteConsoleA(stdout, resize_seq.data as *void, resize_seq.length, (&written) as *void, 0 as *void)
    
    hide_cursor: str = "\x1b[?25l"
    WriteConsoleA(stdout, hide_cursor.data as *void, hide_cursor.length, (&written) as *void, 0 as *void)
    
    title_x32: str = "Garry's Mod"
    title_x64: str = "Garry's Mod (x64)"
    class_name: str = "Valve001"
    
    hWnd: *void = FindWindowA(0 as *void, title_x32.data)
    if hWnd == 0 as *void:
        hWnd = FindWindowA(0 as *void, title_x64.data)
    if hWnd == 0 as *void:
        hWnd = FindWindowA(class_name.data, 0 as *void)
    
    if hWnd == 0 as *void:
        err_msg: str = "ОШИБКА: Окно Garry's Mod не найдено!\n"
        WriteConsoleA(stdout, err_msg.data as *void, err_msg.length, (&written) as *void, 0 as *void)
        return 1
        
    out_w: int = 160
    out_h: int = 90
    
    hdcSrc: *void = GetDC(hWnd)
    hdcDest: *void = CreateCompatibleDC(hdcSrc)
    
    bmi: BITMAPINFOHEADER = {0}
    memset((&bmi) as *void, 0, sizeof(BITMAPINFOHEADER))
    bmi.biSize = 40
    bmi.biWidth = out_w
    bmi.biHeight = out_h 
    bmi.biPlanes = 1 as i16
    bmi.biBitCount = 32 as i16
    bmi.biCompression = 0
    
    ppvBits: *void = 0 as *void
    hBitmap: *void = CreateDIBSection(hdcSrc, (&bmi) as *void, 0, (&ppvBits) as *void, 0 as *void, 0)
    SelectObject(hdcDest, hBitmap)
    
    SetStretchBltMode(hdcDest, 4) 
    SetBrushOrgEx(hdcDest, 0, 0, 0 as *void) 
    
    frame_size: int = 600000 
    frame: *char = malloc(frame_size) as *char
    defer:
        free(frame as *void)
        
    rect: RECT = {0}
    
    sync_start: str = "\x1b[?2026h\x1b[H" 
    sync_end: str = "\x1b[?2026l"         
    reset_seq: str = "\x1b[0m\n"
    restore_cursor: str = "\x1b[?25h"
    
    color_both: str = "\x1b[48;2;%d;%d;%d;38;2;%d;%d;%dm"
    color_bg: str = "\x1b[48;2;%d;%d;%dm"
    color_fg: str = "\x1b[38;2;%d;%d;%dm"
    block_char: str = "▄"
    
    pixels: *u8 = ppvBits as *u8
    
    while 1:
        GetClientRect(hWnd, (&rect) as *void)
        srcW: int = rect.right - rect.left
        srcH: int = rect.bottom - rect.top
        
        StretchBlt(hdcDest, 0, 0, out_w, out_h, hdcSrc, 0, 0, srcW, srcH, 0x00CC0020)
        GdiFlush() 
        
        WriteConsoleA(stdout, sync_start.data as *void, sync_start.length, (&written) as *void, 0 as *void)
        
        f_idx: int = 0
        
        for cy in 0..45:
            last_bg_r: int = -1
            last_bg_g: int = -1
            last_bg_b: int = -1
            
            last_fg_r: int = -1
            last_fg_g: int = -1
            last_fg_b: int = -1
            
            img_y1: int = 89 - (cy * 2)     
            img_y2: int = 89 - (cy * 2 + 1) 
            
            base_i1: int = img_y1 * 160 * 4
            base_i2: int = img_y2 * 160 * 4
            
            for cx in 0..160:
                i1: int = base_i1 + cx * 4
                i2: int = base_i2 + cx * 4
                
                b1: int = ((pixels[i1] as int) & 255) & 248
                g1: int = ((pixels[i1 + 1] as int) & 255) & 248
                r1: int = ((pixels[i1 + 2] as int) & 255) & 248
                
                b2: int = ((pixels[i2] as int) & 255) & 248
                g2: int = ((pixels[i2 + 1] as int) & 255) & 248
                r2: int = ((pixels[i2 + 2] as int) & 255) & 248
                
                bg_changed: int = 0
                fg_changed: int = 0
                
                if r1 != last_bg_r or g1 != last_bg_g or b1 != last_bg_b:
                    bg_changed = 1
                if r2 != last_fg_r or g2 != last_fg_g or b2 != last_fg_b:
                    fg_changed = 1
                    
                if bg_changed == 1 and fg_changed == 1:
                    w_len1: int = sprintf((&frame[f_idx]) as *char, color_both.data as *char, r1, g1, b1, r2, g2, b2)
                    f_idx += w_len1
                    last_bg_r = r1
                    last_bg_g = g1
                    last_bg_b = b1
                    last_fg_r = r2
                    last_fg_g = g2
                    last_fg_b = b2
                else:
                    if bg_changed == 1:
                        w_len2: int = sprintf((&frame[f_idx]) as *char, color_bg.data as *char, r1, g1, b1)
                        f_idx += w_len2
                        last_bg_r = r1
                        last_bg_g = g1
                        last_bg_b = b1
                        
                    if fg_changed == 1:
                        w_len3: int = sprintf((&frame[f_idx]) as *char, color_fg.data as *char, r2, g2, b2)
                        f_idx += w_len3
                        last_fg_r = r2
                        last_fg_g = g2
                        last_fg_b = b2
                
                frame[f_idx] = block_char.data[0]
                frame[f_idx + 1] = block_char.data[1]
                frame[f_idx + 2] = block_char.data[2]
                f_idx += 3
                
            w_len4: int = sprintf((&frame[f_idx]) as *char, reset_seq.data as *char)
            f_idx += w_len4
            
        offset: int = 0
        chunk_size: int = 30000
        
        while offset < f_idx:
            to_write: int = f_idx - offset
            if to_write > chunk_size:
                to_write = chunk_size
                
            WriteConsoleA(stdout, (&frame[offset]) as *void, to_write, (&written) as *void, 0 as *void)
            offset += written
            
        WriteConsoleA(stdout, sync_end.data as *void, sync_end.length, (&written) as *void, 0 as *void)
        
        while _kbhit() != 0:
            key: int = _getch()
            vk: int = 0
            
            if key == 119 or key == 87: 
                vk = 0x57
            if key == 97 or key == 65:  
                vk = 0x41
            if key == 115 or key == 83: 
                vk = 0x53
            if key == 100 or key == 68: 
                vk = 0x44
            if key == 32:               
                vk = 0x20
                
            if key == 27:
                ReleaseDC(hWnd, hdcSrc)
                DeleteDC(hdcDest)
                DeleteObject(hBitmap)
                WriteConsoleA(stdout, reset_seq.data as *void, reset_seq.length, (&written) as *void, 0 as *void)
                WriteConsoleA(stdout, restore_cursor.data as *void, restore_cursor.length, (&written) as *void, 0 as *void)
                return 0
                
            if vk != 0:
                PostMessageA(hWnd, 0x0100, vk, 0)
                PostMessageA(hWnd, 0x0101, vk, 0)
                
        Sleep(10)
        
    ReleaseDC(hWnd, hdcSrc)
    DeleteDC(hdcDest)
    DeleteObject(hBitmap)
    
    return 0
endofcode