import "lib.cbl"

struct MSG:
    hwnd: *void
    message: int
    wParam: *void
    lParam: *void
    time: int
    pt_x: int
    pt_y: int

struct WNDCLASSA:
    style: int
    lpfnWndProc: *void
    cbClsExtra: int
    cbWndExtra: int
    hInstance: *void
    hIcon: *void
    hCursor: *void
    hbrBackground: *void
    lpszMenuName: *void
    lpszClassName: *void

const WM_DESTROY: int = 2
const WM_CLOSE: int = 16
const WM_QUIT: int = 18
const WM_ERASEBKGND: int = 20

extern def wglUseFontBitmapsA(hdc: *void, first: int, count: int, listBase: int) -> int
extern def glListBase(base: int) -> void
extern def glCallLists(n: int, type: int, lists: *void) -> void
extern def glRasterPos2d(x: f64, y: f64) -> void
extern def glDepthMask(flag: int) -> void
extern def CreateFontA(cHeight: int, cWidth: int, cEscapement: int, cOrientation: int, cWeight: int, bItalic: int, bUnderline: int, bStrikeOut: int, iCharSet: int, iOutPrecision: int, iClipPrecision: int, iQuality: int, iPitchAndFamily: int, pszFaceName: *void) -> *void
extern def SelectObject(hdc: *void, h: *void) -> *void
extern def GetTickCount() -> int
extern def sqrt(x: f64) -> f64
extern def atan2(y: f64, x: f64) -> f64
extern def fabs(x: f64) -> f64

def custom_wnd_proc(hwnd: *void, msg_code: int, w_param: *void, l_param: *void) -> int:
    if msg_code == WM_ERASEBKGND:
        return 1
        
    if msg_code == WM_CLOSE:
        PostQuitMessage(0)
        endofcode
    if msg_code == WM_DESTROY:
        PostQuitMessage(0)
        endofcode
    return DefWindowProcA(hwnd, msg_code, w_param, l_param)

const WINDOW_W: int = 960
const WINDOW_H: int = 720
const MAP_WIDTH: int = 32
const MAP_HEIGHT: int = 32

world_map: *int = [
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
    1,0,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
    1,0,1,0,0,0,0,0,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,
    1,0,1,0,1,1,1,1,1,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
    1,0,1,0,1,0,0,0,1,0,0,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,
    1,0,1,0,1,0,1,0,1,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
    1,0,1,0,1,0,1,0,1,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,
    1,0,1,0,1,0,1,0,1,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
    1,0,1,0,1,0,1,0,1,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,
    1,0,1,0,1,0,1,0,1,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
    1,0,1,0,1,0,1,0,1,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,
    1,0,1,0,1,0,1,0,1,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
    1,0,1,0,1,0,1,0,1,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
    1,0,1,1,1,0,1,1,1,0,1,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,0,0,0,0,0,1,
    1,0,0,0,0,0,0,0,0,0,1,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,0,0,0,0,0,1,
    1,1,1,1,1,0,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
    1,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,1,0,1,1,1,1,1,1,0,0,1,1,1,0,1,
    1,0,1,1,1,1,1,0,1,1,1,0,0,0,1,0,0,1,0,0,0,0,0,0,1,0,0,1,0,0,0,1,
    1,0,1,0,0,0,1,0,1,0,0,0,1,0,1,0,0,1,1,1,1,1,1,0,1,0,0,1,0,1,1,1,
    1,0,1,0,1,0,1,0,1,0,1,1,1,0,1,0,0,0,0,0,0,0,0,0,1,0,0,1,0,0,0,1,
    1,0,1,0,1,0,0,0,1,0,0,0,0,0,1,0,0,1,1,1,1,0,1,1,1,0,0,1,1,1,0,1,
    1,0,1,0,1,1,1,1,1,1,1,1,1,0,1,0,0,1,0,0,0,0,1,0,0,0,0,0,0,1,0,1,
    1,0,0,0,0,0,0,0,0,0,0,0,1,0,1,0,0,1,0,1,1,1,1,0,1,1,1,1,0,1,0,1,
    1,0,1,1,1,1,1,1,1,1,1,0,1,0,1,0,0,1,0,0,0,0,0,0,1,0,0,0,0,1,0,1,
    1,0,1,0,0,0,0,0,0,0,1,0,1,0,1,0,0,1,1,1,1,1,1,1,1,0,1,1,1,1,0,1,
    1,0,1,0,1,1,1,1,1,0,1,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,
    1,0,1,0,1,0,0,0,1,0,1,0,1,1,1,1,1,1,1,1,0,1,1,1,1,1,1,0,1,1,1,1,
    1,0,1,0,1,0,1,0,1,0,1,0,0,0,0,0,0,0,0,1,0,1,0,0,0,0,0,0,1,0,0,1,
    1,0,0,0,0,0,1,0,0,0,1,0,1,1,1,1,1,1,0,1,0,1,0,1,1,1,1,1,1,0,0,1,
    1,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
]

def get_map(x: int, y: int) -> int:
    if 0 > x:
        return 1
    if x >= MAP_WIDTH:
        return 1
    if 0 > y:
        return 1
    if y >= MAP_HEIGHT:
        return 1
    return world_map[y * MAP_WIDTH + x]

def noise(x: int, y: int) -> f64:
    n: int = x * 137 + y * 281
    n = n % 8192
    n = (n * n * 41 + n * 11)
    n = n % 1000
    if 0 > n:
        n = 0 - n
    return (n as f64) / 1000.0

def create_texture(type_id: int) -> int:
    tex_id: *int = malloc(4)
    glGenTextures(1, tex_id)
    glBindTexture(3553, tex_id[0]) 
    glTexParameteri(3553, 10241, 9728) 
    glTexParameteri(3553, 10240, 9728)
    glTexParameteri(3553, 10242, 10497) 
    glTexParameteri(3553, 10243, 10497)

    buf: *int = malloc(16384) 
    y: int = 0
    while 64 > y:
        x: int = 0
        while 64 > x:
            r: int = 0
            g: int = 0
            b: int = 0
            a: int = 255
            
            if type_id == 1:
                col_r: f64 = 200.0
                col_g: f64 = 170.0
                col_b: f64 = 60.0
                
                if (x % 16) > 14:
                    col_r = 170.0
                    col_g = 140.0
                    col_b = 40.0
                
                if noise(x * 5, y * 2) > 0.7:
                    col_r = col_r * 0.85
                    col_g = col_g * 0.85
                    col_b = col_b * 0.85

                if y > 58:
                    col_r = 50.0
                    col_g = 30.0
                    col_b = 10.0
                    
                r = col_r as int
                g = col_g as int
                b = col_b as int
            
            if type_id == 2:
                n_f: f64 = noise(x * 15, y * 15)
                r = (130.0 + n_f * 40.0) as int
                g = (110.0 + n_f * 30.0) as int
                b = (60.0  + n_f * 20.0) as int
            
            if type_id == 3:
                r = 150
                g = 140
                b = 120
                if (x % 32) < 2:
                    r = 90
                    g = 80
                    b = 70
                if (y % 32) < 2:
                    r = 90
                    g = 80
                    b = 70
                    
                if x > 8:
                    if 24 > x:
                        if y > 4:
                            if 60 > y:
                                r = 255
                                g = 255
                                b = 240
                
            if type_id == 4:
                u_e: f64 = (x as f64) / 64.0
                v_e: f64 = (y as f64) / 64.0
                r = 0
                g = 0
                b = 0
                a = 0
                
                dist_c: f64 = (u_e - 0.5)*(u_e - 0.5)*4.0 + (v_e - 0.5)*(v_e - 0.5)
                if 0.08 > dist_c:
                    a = 255
                
                if noise(x * 15, y * 15) > 0.65:
                    if 0.4 > dist_c:
                        a = 255
            
            if type_id == 5:
                dx: f64 = ((x as f64) - 32.0) / 32.0
                dy: f64 = ((y as f64) - 32.0) / 32.0
                dist_sq_v: f64 = dx * dx + dy * dy
                if dist_sq_v > 1.0:
                    dist_sq_v = 1.0
                r = 0
                g = 0
                b = 0
                a = (dist_sq_v * 250.0) as int 

            if type_id == 6:
                if (y % 4) == 0:
                    r = 0
                    g = 0
                    b = 0
                    a = 140 
                else:
                    n_val: int = rand() % 255
                    r = n_val
                    g = n_val
                    b = n_val
                    a = 40 
                    
            if type_id == 7:
                r = 255
                g = 240
                b = 200
                a = 0
                rnd_v: int = rand() % 1000
                if rnd_v > 990:
                    a = 150 + (rand() % 100)
                
            if r > 255:
                r = 255
            if g > 255:
                g = 255
            if b > 255:
                b = 255
            if 0 > r:
                r = 0
            if 0 > g:
                g = 0
            if 0 > b:
                b = 0
            
            buf[y * 64 + x] = r + g * 256 + b * 65536 + a * 16777216
            x = x + 1
        y = y + 1
        
    glTexImage2D(3553, 0, 6408, 64, 64, 0, 6408, 5121, buf)
    res: int = tex_id[0]
    free(buf)
    free(tex_id)
    return res

def draw_text(x: f64, y: f64, text: str, r: f64, g: f64, b: f64, a: f64) -> void:
    glDisable(3553)
    glColor4d(r, g, b, a)
    glRasterPos2d(x, y)
    glListBase(1000)
    glCallLists(text.length, 5121, text.data as *void)
    glEnable(3553)

def draw_char(x: f64, y: f64, char_ptr: *void, r: f64, g: f64, b: f64, a: f64) -> void:
    glDisable(3553)
    glColor4d(r, g, b, a)
    glRasterPos2d(x, y)
    glListBase(1000)
    glCallLists(1, 5121, char_ptr)
    glEnable(3553)

def get_vertex_light(vx: f64, vy: f64, px: f64, py: f64, pa: f64, flash_on: int) -> f64:
    lx: f64 = vx / 2.0
    ly: f64 = vy / 2.0
    lx_int: int = lx as int
    ly_int: int = ly as int
    
    lamp_x: f64 = (lx_int as f64) * 2.0 + 0.5
    lamp_y: f64 = (ly_int as f64) * 2.0 + 1.0
    
    dx_l: f64 = vx - lamp_x
    dy_l: f64 = vy - lamp_y
    dist_sq_l: f64 = dx_l * dx_l + dy_l * dy_l
    
    lamp_power: f64 = 0.95
    rnd: int = (lx_int * 7 + ly_int * 13) % 10
    if rnd > 7:
        lamp_power = 0.0 
    
    if rnd == 7:
        time_s: int = GetTickCount()
        blink: f64 = sin((time_s as f64) * 0.015)
        if blink > 0.0:
            lamp_power = 0.0
        
    illum: f64 = 0.02 + lamp_power / (dist_sq_l * 1.5 + 1.0)
    
    dx_p: f64 = vx - px
    dy_p: f64 = vy - py
    dist_p_sq: f64 = dx_p * dx_p + dy_p * dy_p
    
    fade: f64 = 1.0 - (dist_p_sq / 25.0) 
    if 0.0 > fade: 
        fade = 0.0
        
    flash_illum: f64 = 0.0
    if flash_on == 1:
        if 36.0 > dist_p_sq: 
            dist_p: f64 = sqrt(dist_p_sq)
            if dist_p > 0.1:
                v_angle: f64 = atan2(dx_p, dy_p) 
                diff: f64 = v_angle - pa
                while diff > 3.14159: 
                    diff = diff - 6.2831853
                while -3.14159 > diff: 
                    diff = diff + 6.2831853
                
                if 0.35 > diff:
                    if diff > -0.35:
                        spot: f64 = 1.0 - (dist_p / 6.0)
                        if spot > 0.0:
                            edge: f64 = 1.0 - (fabs(diff) / 0.35)
                            edge = edge * edge 
                            flash_illum = spot * edge * 2.5
                            
    illum = (illum * fade) + flash_illum
    illum = illum * illum * 1.8
    
    if illum > 1.0: 
        illum = 1.0
    return illum

def draw_world(t_wall: int, t_floor: int, t_ceil: int, px: f64, py: f64, pa: f64, fov: f64, vis_map: *int, level_type: int, hole_x: int, hole_y: int, flash_on: int) -> void:
    i: int = 0
    while 1024 > i:
        vis_map[i] = 0
        i = i + 1

    y_v: int = 0
    while MAP_HEIGHT > y_v:
        x_v: int = 0
        while MAP_WIDTH > x_v:
            dx_v: f64 = (x_v as f64) + 0.5 - px
            dy_v: f64 = (y_v as f64) + 0.5 - py
            if 300.0 > (dx_v * dx_v + dy_v * dy_v):
                vis_map[y_v * MAP_WIDTH + x_v] = 1
            x_v = x_v + 1
        y_v = y_v + 1

    y_d: int = 0
    x_d: int = 0
    idx_w: int = 0
    xf: f64 = 0.0
    yf: f64 = 0.0
    l00: f64 = 0.0
    l10: f64 = 0.0
    l11: f64 = 0.0
    l01: f64 = 0.0
    l0: f64 = 0.0
    l1: f64 = 0.0

    glBindTexture(3553, t_floor)
    glBegin(7)
    y_d = 0
    while MAP_HEIGHT > y_d:
        x_d = 0
        while MAP_WIDTH > x_d:
            idx_w = y_d * MAP_WIDTH + x_d
            if vis_map[idx_w] == 1:
                if world_map[idx_w] == 0:
                    xf = x_d as f64
                    yf = y_d as f64
                    
                    l00 = get_vertex_light(xf, yf, px, py, pa, flash_on)
                    l10 = get_vertex_light(xf + 1.0, yf, px, py, pa, flash_on)
                    l11 = get_vertex_light(xf + 1.0, yf + 1.0, px, py, pa, flash_on)
                    l01 = get_vertex_light(xf, yf + 1.0, px, py, pa, flash_on)
                    
                    glColor3d(l00, l00, l00)
                    glTexCoord2d(xf, yf)
                    glVertex3d(xf, 0.0, yf)
                    
                    glColor3d(l10, l10, l10)
                    glTexCoord2d(xf + 1.0, yf)
                    glVertex3d(xf + 1.0, 0.0, yf)
                    
                    glColor3d(l11, l11, l11)
                    glTexCoord2d(xf + 1.0, yf + 1.0)
                    glVertex3d(xf + 1.0, 0.0, yf + 1.0)
                    
                    glColor3d(l01, l01, l01)
                    glTexCoord2d(xf, yf + 1.0)
                    glVertex3d(xf, 0.0, yf + 1.0)
            x_d = x_d + 1
        y_d = y_d + 1
    glEnd()

    glBindTexture(3553, t_ceil)
    glBegin(7)
    y_d = 0
    while MAP_HEIGHT > y_d:
        x_d = 0
        while MAP_WIDTH > x_d:
            idx_w = y_d * MAP_WIDTH + x_d
            if vis_map[idx_w] == 1:
                if world_map[idx_w] == 0:
                    xf = x_d as f64
                    yf = y_d as f64
                    
                    l00 = get_vertex_light(xf, yf, px, py, pa, flash_on)
                    l10 = get_vertex_light(xf + 1.0, yf, px, py, pa, flash_on)
                    l11 = get_vertex_light(xf + 1.0, yf + 1.0, px, py, pa, flash_on)
                    l01 = get_vertex_light(xf, yf + 1.0, px, py, pa, flash_on)
                    
                    glColor3d(l00, l00, l00)
                    glTexCoord2d(xf / 2.0, yf / 2.0)
                    glVertex3d(xf, 1.0, yf)
                    
                    glColor3d(l10, l10, l10)
                    glTexCoord2d((xf + 1.0) / 2.0, yf / 2.0)
                    glVertex3d(xf + 1.0, 1.0, yf)
                    
                    glColor3d(l11, l11, l11)
                    glTexCoord2d((xf + 1.0) / 2.0, (yf + 1.0) / 2.0)
                    glVertex3d(xf + 1.0, 1.0, yf + 1.0)
                    
                    glColor3d(l01, l01, l01)
                    glTexCoord2d(xf / 2.0, (yf + 1.0) / 2.0)
                    glVertex3d(xf, 1.0, yf + 1.0)
            x_d = x_d + 1
        y_d = y_d + 1
    glEnd()

    glBindTexture(3553, t_wall)
    glBegin(7)
    y_d = 0
    while MAP_HEIGHT > y_d:
        x_d = 0
        while MAP_WIDTH > x_d:
            idx_w = y_d * MAP_WIDTH + x_d
            if vis_map[idx_w] == 1:
                if world_map[idx_w] > 0:
                    xf = x_d as f64
                    yf = y_d as f64
                    
                    if get_map(x_d, y_d - 1) == 0:
                        l0 = get_vertex_light(xf, yf, px, py, pa, flash_on)
                        l1 = get_vertex_light(xf + 1.0, yf, px, py, pa, flash_on)
                        
                        glColor3d(l0, l0, l0)
                        glTexCoord2d(0.0, 1.0)
                        glVertex3d(xf, 0.0, yf)
                        
                        glColor3d(l1, l1, l1)
                        glTexCoord2d(1.0, 1.0)
                        glVertex3d(xf + 1.0, 0.0, yf)
                        
                        glColor3d(l1, l1, l1)
                        glTexCoord2d(1.0, 0.0)
                        glVertex3d(xf + 1.0, 1.0, yf)
                        
                        glColor3d(l0, l0, l0)
                        glTexCoord2d(0.0, 0.0)
                        glVertex3d(xf, 1.0, yf)

                    if get_map(x_d, y_d + 1) == 0:
                        l0 = get_vertex_light(xf + 1.0, yf + 1.0, px, py, pa, flash_on)
                        l1 = get_vertex_light(xf, yf + 1.0, px, py, pa, flash_on)
                        
                        glColor3d(l0, l0, l0)
                        glTexCoord2d(0.0, 1.0)
                        glVertex3d(xf + 1.0, 0.0, yf + 1.0)
                        
                        glColor3d(l1, l1, l1)
                        glTexCoord2d(1.0, 1.0)
                        glVertex3d(xf, 0.0, yf + 1.0)
                        
                        glColor3d(l1, l1, l1)
                        glTexCoord2d(1.0, 0.0)
                        glVertex3d(xf, 1.0, yf + 1.0)
                        
                        glColor3d(l0, l0, l0)
                        glTexCoord2d(0.0, 0.0)
                        glVertex3d(xf + 1.0, 1.0, yf + 1.0)

                    if get_map(x_d - 1, y_d) == 0:
                        l0 = get_vertex_light(xf, yf + 1.0, px, py, pa, flash_on)
                        l1 = get_vertex_light(xf, yf, px, py, pa, flash_on)
                        
                        glColor3d(l0, l0, l0)
                        glTexCoord2d(0.0, 1.0)
                        glVertex3d(xf, 0.0, yf + 1.0)
                        
                        glColor3d(l1, l1, l1)
                        glTexCoord2d(1.0, 1.0)
                        glVertex3d(xf, 0.0, yf)
                        
                        glColor3d(l1, l1, l1)
                        glTexCoord2d(1.0, 0.0)
                        glVertex3d(xf, 1.0, yf)
                        
                        glColor3d(l0, l0, l0)
                        glTexCoord2d(0.0, 0.0)
                        glVertex3d(xf, 1.0, yf + 1.0)

                    if get_map(x_d + 1, y_d) == 0:
                        l0 = get_vertex_light(xf + 1.0, yf, px, py, pa, flash_on)
                        l1 = get_vertex_light(xf + 1.0, yf + 1.0, px, py, pa, flash_on)
                        
                        glColor3d(l0, l0, l0)
                        glTexCoord2d(0.0, 1.0)
                        glVertex3d(xf + 1.0, 0.0, yf)
                        
                        glColor3d(l1, l1, l1)
                        glTexCoord2d(1.0, 1.0)
                        glVertex3d(xf + 1.0, 0.0, yf + 1.0)
                        
                        glColor3d(l1, l1, l1)
                        glTexCoord2d(1.0, 0.0)
                        glVertex3d(xf + 1.0, 1.0, yf + 1.0)
                        
                        glColor3d(l0, l0, l0)
                        glTexCoord2d(0.0, 0.0)
                        glVertex3d(xf + 1.0, 1.0, yf)
            x_d = x_d + 1
        y_d = y_d + 1
    glEnd()

    if level_type == 0:
        glDisable(3553)
        glColor3d(0.0, 0.0, 0.0)
        glBegin(7)
        hxf: f64 = hole_x as f64
        hyf: f64 = hole_y as f64
        glVertex3d(hxf, 0.01, hyf)
        glVertex3d(hxf + 1.0, 0.01, hyf)
        glVertex3d(hxf + 1.0, 0.01, hyf + 1.0)
        glVertex3d(hxf, 0.01, hyf + 1.0)
        glEnd()
        glEnable(3553)

def main() -> int:
    console_hwnd: *void = GetConsoleWindow()
    ShowWindow(console_hwnd, 0)
    
    vis_map: *int = malloc(4096)
    
    wave_buf_idle_32: *u32 = malloc(16500) as *u32
    wave_buf_walk_32: *u32 = malloc(16500) as *u32
    wave_buf_run_32: *u32 = malloc(16500) as *u32
    wave_buf_mon_32: *u32 = malloc(16500) as *u32
    
    wave_buf_idle_32[0] = 1179011410
    wave_buf_idle_32[1] = 16420
    wave_buf_idle_32[2] = 1163280727
    wave_buf_idle_32[3] = 544501094
    wave_buf_idle_32[4] = 16
    wave_buf_idle_32[5] = 65537
    wave_buf_idle_32[6] = 8192
    wave_buf_idle_32[7] = 8192
    wave_buf_idle_32[8] = 524289
    wave_buf_idle_32[9] = 1635017060
    wave_buf_idle_32[10] = 16384
    
    i_h: int = 0
    while 11 > i_h:
        wave_buf_walk_32[i_h] = wave_buf_idle_32[i_h]
        wave_buf_run_32[i_h] = wave_buf_idle_32[i_h]
        wave_buf_mon_32[i_h] = wave_buf_idle_32[i_h]
        i_h = i_h + 1
        
    data_idle: *u8 = wave_buf_idle_32 as *u8
    data_walk: *u8 = wave_buf_walk_32 as *u8
    data_run: *u8 = wave_buf_run_32 as *u8
    data_mon: *u8 = wave_buf_mon_32 as *u8

    wi: int = 0
    while 16384 > wi:
        t: f64 = (wi as f64) / 8192.0
        sf: f64 = sin(t * 170.0 * 6.2831853) * 0.4 + sin(t * 60.0 * 6.2831853) * 0.3
        
        t_w: f64 = t + 0.25
        if t_w >= 1.0:
            t_w = t_w - 1.0
        beat_w: f64 = t_w * 2.0
        beat_w_int: int = beat_w as int
        beat_w = beat_w - (beat_w_int as f64)
        thud_w: f64 = 0.0
        if 0.25 > beat_w:
            env_w: f64 = 1.0
            if 0.03 > beat_w:
                env_w = beat_w / 0.03
            else:
                env_w = 1.0 - ((beat_w - 0.03) / 0.22)
            thud_w = sin(beat_w * 45.0 * 6.2831853) * env_w * env_w * 1.5
            
        t_r: f64 = t + 0.166666
        if t_r >= 1.0:
            t_r = t_r - 1.0
        beat_r: f64 = t_r * 3.0
        beat_r_int: int = beat_r as int
        beat_r = beat_r - (beat_r_int as f64)
        thud_r: f64 = 0.0
        if 0.15 > beat_r:
            env_r: f64 = 1.0
            if 0.02 > beat_r:
                env_r = beat_r / 0.02
            else:
                env_r = 1.0 - ((beat_r - 0.02) / 0.13)
            thud_r = sin(beat_r * 55.0 * 6.2831853) * env_r * env_r * 1.8
            
        s_i: f64 = sf
        s_w: f64 = sf + thud_w
        s_r: f64 = sf + thud_r
        
        if s_i > 1.0:
            s_i = 1.0
        if -1.0 > s_i:
            s_i = -1.0
        if s_w > 1.0:
            s_w = 1.0
        if -1.0 > s_w:
            s_w = -1.0
        if s_r > 1.0:
            s_r = 1.0
        if -1.0 > s_r:
            s_r = -1.0
        
        data_idle[44 + wi] = (s_i * 80.0 + 128.0) as u8
        data_walk[44 + wi] = (s_w * 80.0 + 128.0) as u8
        data_run[44 + wi] = (s_r * 80.0 + 128.0) as u8
        wi = wi + 1

    cls_name: *void = "CBLGameClass".data as *void
    win_name: *void = "Backrooms. The Found Footage.".data as *void
    
    h_inst: *void = GetModuleHandleA(0 as *void)
    
    wc: *WNDCLASSA = malloc(sizeof(WNDCLASSA))
    wc.style = 3
    wc.lpfnWndProc = custom_wnd_proc as *void
    wc.cbClsExtra = 0
    wc.cbWndExtra = 0
    wc.hInstance = h_inst
    wc.hIcon = 0 as *void
    wc.hCursor = 0 as *void
    wc.hbrBackground = 0 as *void
    wc.lpszMenuName = 0 as *void
    wc.lpszClassName = cls_name
    
    RegisterClassA(wc as *void)
    free(wc)

    hwnd: *void = CreateWindowExA(0, cls_name, win_name, 282001408, 100, 100, WINDOW_W, WINDOW_H, 0 as *void, 0 as *void, h_inst, 0 as *void)
    hdc: *void = GetDC(hwnd)
    
    pfd: *int = malloc(40)
    pfd[0] = 65576 
    pfd[1] = 37    
    pfd[2] = 8192  
    pfd[3] = 0
    pfd[4] = 0
    pfd[5] = 0
    pfd[6] = 0
    pfd[7] = 0
    pfd[8] = 0
    pfd[9] = 0

    pixel_format: int = ChoosePixelFormat(hdc, pfd)
    SetPixelFormat(hdc, pixel_format, pfd)
    hrc: *void = wglCreateContext(hdc)
    wglMakeCurrent(hdc, hrc)
    free(pfd)
    
    hfont: *void = CreateFontA(24, 0, 0, 0, 700, 0, 0, 0, 1, 0, 0, 3, 0, "Consolas".data as *void)
    SelectObject(hdc, hfont)

    wglUseFontBitmapsA(hdc, 0, 255, 1000)
    
    glEnable(2929) 
    glEnable(3553) 
    
    glClearColor(0.01 as float, 0.01 as float, 0.01 as float, 1.0 as float)
    glViewport(0, 0, WINDOW_W, WINDOW_H)

    tex_wall: int = create_texture(1)
    tex_floor: int = create_texture(2)
    tex_ceil: int = create_texture(3)
    tex_ent: int = create_texture(4)
    tex_vig: int = create_texture(5)
    tex_vhs: int = create_texture(6)
    tex_dust: int = create_texture(7)

    PlaySoundA(wave_buf_idle_32 as *void, 0 as *void, 13)

    msg_raw: *int = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    msg_ptr: *MSG = msg_raw as *MSG
    msg_void: *void = msg_raw as *void

    game_state: int = 0         
    resume_state: int = 1
    state_timer: f64 = 0.0
    tutorial_timer: f64 = 0.0
    level_type: int = 0
    
    flashlight_on: int = 0
    flashlight_battery: f64 = 100.0
    f_key_debounce: int = 0
    flash_a: f64 = 0.0
    flash_pitch: f64 = 0.0
    
    hole_x: int = 0
    hole_y: int = 0
    hole_found: int = 0
    
    while hole_found == 0:
        hole_x = rand() % MAP_WIDTH
        hole_y = rand() % MAP_HEIGHT
        if get_map(hole_x, hole_y) == 0:
            is_start: int = 0
            if hole_x == 1:
                if hole_y == 1:
                    is_start = 1
            if is_start == 0:
                hole_found = 1

    menu_debounce: int = 0
    bind_target: int = 0
    cursor_visible: int = 1
    
    is_fullscreen: int = 0
    f11_debounce: int = 0
    current_w: int = WINDOW_W
    current_h: int = WINDOW_H

    key_fwd: int = 87 
    key_bck: int = 83 
    key_lft: int = 65 
    key_rgt: int = 68 
    mouse_sens: f64 = 0.003

    pt: *int = malloc(8)        
    key_buf: *int = malloc(4)   
    key_buf[0] = 0

    player_x: f64 = 1.5
    player_y: f64 = 1.5
    player_a: f64 = 0.0
    
    target_player_a: f64 = 0.0
    target_pitch_offset: f64 = 0.0
    current_pitch_offset: f64 = 0.0
    
    fov: f64 = 1.5    

    bob_timer: f64 = 0.0
    tremor_timer: f64 = 0.0
    
    is_running: int = 1
    last_move_state: int = -1

    ent_x: f64 = 0.0
    ent_y: f64 = 0.0
    ent_active: int = 0
    ent_state: int = 0
    ent_timer: f64 = 0.0
    ent_audio_timer: f64 = 1.0
    
    jumpscare_frames: int = 0
    last_time: int = GetTickCount()

    while is_running == 1:
        curr_time: int = GetTickCount()
        delta_ms: int = curr_time - last_time
        last_time = curr_time
        delta_s: f64 = (delta_ms as f64) / 1000.0
        
        frame_start: int = GetTickCount()
        
        while PeekMessageA(msg_void, 0 as *void, 0, 0, 1) != 0:
            if msg_ptr.message == WM_QUIT:
                is_running = 0
            DispatchMessageA(msg_void)

        if f11_debounce > 0:
            f11_debounce = f11_debounce - 1

        if GetAsyncKeyState(122) != 0: 
            if f11_debounce == 0:
                if is_fullscreen == 0:
                    is_fullscreen = 1
                    sw: int = GetSystemMetrics(0)
                    sh: int = GetSystemMetrics(1)
                    SetWindowLongA(hwnd, -16, -1879048192) 
                    SetWindowPos(hwnd, 0 as *void, 0, 0, sw, sh, 100)
                    current_w = sw
                    current_h = sh
                    glViewport(0, 0, sw, sh)
                else:
                    is_fullscreen = 0
                    SetWindowLongA(hwnd, -16, 282001408)
                    SetWindowPos(hwnd, 0 as *void, 100, 100, WINDOW_W, WINDOW_H, 100)
                    current_w = WINDOW_W
                    current_h = WINDOW_H
                    glViewport(0, 0, WINDOW_W, WINDOW_H)
                f11_debounce = 30

        if menu_debounce > 0:
            menu_debounce = menu_debounce - 1

        is_playing: int = 0
        if game_state == 1:
            is_playing = 1
        if game_state == 4:
            is_playing = 1
        if game_state == 5:
            is_playing = 1
        if game_state == 6:
            is_playing = 1

        if GetAsyncKeyState(27) != 0:
            if menu_debounce == 0:
                if is_playing == 1:
                    resume_state = game_state
                    game_state = 0
                else:
                    if game_state == 0:
                        game_state = resume_state
                menu_debounce = 15

        if game_state == 0:
            if GetAsyncKeyState(49) != 0:
                if menu_debounce == 0: 
                    game_state = 4
                    state_timer = 0.0
                    tutorial_timer = 0.0
                    player_x = 1.5
                    player_y = 1.5
                    player_a = 0.0
                    target_player_a = 0.0
                    level_type = 0
                    flash_a = 0.0
                    flash_pitch = -280.0
                    menu_debounce = 15
            if GetAsyncKeyState(50) != 0:
                if menu_debounce == 0: 
                    game_state = 2
                    menu_debounce = 15
            if GetAsyncKeyState(51) != 0:
                if menu_debounce == 0: 
                    is_running = 0

        if game_state == 2:
            if GetAsyncKeyState(49) != 0:
                if menu_debounce == 0: 
                    mouse_sens = mouse_sens + 0.001
                    if mouse_sens > 0.01:
                        mouse_sens = 0.001
                    menu_debounce = 15
            if GetAsyncKeyState(50) != 0:
                if menu_debounce == 0: 
                    game_state = 3
                    bind_target = 1
                    menu_debounce = 15
            if GetAsyncKeyState(51) != 0:
                if menu_debounce == 0: 
                    game_state = 3
                    bind_target = 2
                    menu_debounce = 15
            if GetAsyncKeyState(52) != 0:
                if menu_debounce == 0: 
                    game_state = 3
                    bind_target = 3
                    menu_debounce = 15
            if GetAsyncKeyState(53) != 0:
                if menu_debounce == 0: 
                    game_state = 3
                    bind_target = 4
                    menu_debounce = 15
            if GetAsyncKeyState(54) != 0:
                if menu_debounce == 0: 
                    game_state = 0
                    menu_debounce = 15

        if game_state == 3:
            k: int = 8
            while 255 > k:
                if GetAsyncKeyState(k) != 0:
                    if menu_debounce == 0:
                        if bind_target == 1:
                            key_fwd = k
                        if bind_target == 2:
                            key_bck = k
                        if bind_target == 3:
                            key_lft = k
                        if bind_target == 4:
                            key_rgt = k
                        game_state = 2
                        menu_debounce = 15
                        k = 256
                k = k + 1

        if is_playing == 1:
            if cursor_visible == 1:
                ShowCursor(0)
                cursor_visible = 0
        if is_playing == 0:
            if cursor_visible == 0:
                ShowCursor(1)
                cursor_visible = 1

        if f_key_debounce > 0:
            f_key_debounce = f_key_debounce - 1
            
        if is_playing == 1:
            if jumpscare_frames == 0:
                if GetAsyncKeyState(70) != 0:
                    if f_key_debounce == 0:
                        if flashlight_on == 1:
                            flashlight_on = 0
                        else:
                            if flashlight_battery > 0.0:
                                flashlight_on = 1
                        f_key_debounce = 15

            if flashlight_on == 1:
                flashlight_battery = flashlight_battery - delta_s * 1.5
                if 0.0 > flashlight_battery:
                    flashlight_battery = 0.0
                    flashlight_on = 0
            else:
                flashlight_battery = flashlight_battery + delta_s * 0.5
                if flashlight_battery > 100.0:
                    flashlight_battery = 100.0

        can_move: int = 0
        if game_state == 1:
            can_move = 1
        if game_state == 6:
            can_move = 1

        is_moving: int = 0
        if can_move == 1:
            if jumpscare_frames == 0:
                if GetAsyncKeyState(key_fwd) != 0:
                    is_moving = 1
                if GetAsyncKeyState(key_bck) != 0:
                    is_moving = 1
                if GetAsyncKeyState(key_lft) != 0:
                    is_moving = 1
                if GetAsyncKeyState(key_rgt) != 0:
                    is_moving = 1

        move_state: int = 0
        if is_moving == 1:
            if GetAsyncKeyState(16) != 0:
                move_state = 2
            else:
                move_state = 1
        else:
            move_state = 0
            
        move_speed: f64 = 0.02
        bob_amp: f64 = 0.03
        
        if move_state == 2: 
            move_speed = 0.045
            bob_amp = 0.06

        target_fov: f64 = 1.3
        if GetAsyncKeyState(1) != 0:
            target_fov = 0.6
        if GetAsyncKeyState(2) != 0:
            target_fov = 1.8
            
        fov = fov + (target_fov - fov) * (delta_s * 6.0)

        if move_state != last_move_state:
            if jumpscare_frames == 0:
                if can_move == 1:
                    last_move_state = move_state
                    bob_timer = 3.14159 
                    if ent_state == 0:
                        if move_state == 2:
                            PlaySoundA(wave_buf_run_32 as *void, 0 as *void, 13)
                        if move_state == 1:
                            PlaySoundA(wave_buf_walk_32 as *void, 0 as *void, 13)
                        if move_state == 0:
                            PlaySoundA(wave_buf_idle_32 as *void, 0 as *void, 13)

        if is_moving == 1:
            if move_state == 2:
                bob_timer = bob_timer + delta_s * 18.8495559
            else:
                bob_timer = bob_timer + delta_s * 12.5663706

        if player_x > 1.0:
            if 2.0 > player_x:
                if player_y > 28.0:
                    player_y = 2.0 
        if player_x > 3.0:
            if 5.0 > player_x:
                if player_y > 1.0:
                    if 2.0 > player_y:
                        view_dir: f64 = sin(player_a)
                        if view_dir > 0.5:
                            world_map[1 * MAP_WIDTH + 2] = 1
                        if -0.5 > view_dir:
                            world_map[1 * MAP_WIDTH + 2] = 0

        if game_state == 4:
            state_timer = state_timer + delta_s
            if state_timer < 1.0:
                t_f: f64 = state_timer / 1.0
                target_pitch_offset = -280.0 * (t_f * t_f)
                current_pitch_offset = target_pitch_offset
            else:
                if state_timer < 3.0:
                    t_f: f64 = (state_timer - 1.0) / 2.0
                    ease: f64 = t_f * t_f * (3.0 - 2.0 * t_f)
                    target_pitch_offset = -280.0 * (1.0 - ease)
                    current_pitch_offset = target_pitch_offset
                else:
                    game_state = 1
                    tutorial_timer = 0.0

        if game_state == 5:
            state_timer = state_timer + delta_s
            t_f: f64 = state_timer / 2.0
            target_pitch_offset = 280.0 * t_f
            current_pitch_offset = target_pitch_offset
            if state_timer > 2.0:
                game_state = 6 
                level_type = 1
                player_x = 1.5
                player_y = 1.5
                player_a = 0.0
                target_player_a = 0.0
                target_pitch_offset = 0.0
                current_pitch_offset = 0.0
                state_timer = 0.0

        if is_playing == 1:
            if jumpscare_frames == 0:
                pt[0] = current_w / 2
                pt[1] = current_h / 2
                ClientToScreen(hwnd, pt as *void)
                c_x: int = pt[0]
                c_y: int = pt[1]

                GetCursorPos(pt as *void)
                d_x: int = pt[0] - c_x
                d_y: int = pt[1] - c_y

                if d_x != 0:
                    target_player_a = target_player_a - (d_x as f64) * mouse_sens
                    SetCursorPos(c_x, c_y)
                if d_y != 0:
                    target_pitch_offset = target_pitch_offset + (d_y as f64) * mouse_sens * 60.0
                    if target_pitch_offset > 80.0:
                        target_pitch_offset = 80.0
                    if -80.0 > target_pitch_offset:
                        target_pitch_offset = -80.0
                    SetCursorPos(c_x, c_y)

        if can_move == 1:
            player_a = player_a + (target_player_a - player_a) * (delta_s * 15.0)
            current_pitch_offset = current_pitch_offset + (target_pitch_offset - current_pitch_offset) * (delta_s * 15.0)

        if is_playing == 1:
            flash_a = flash_a + (player_a - flash_a) * (delta_s * 12.0)
            flash_pitch = flash_pitch + (current_pitch_offset - flash_pitch) * (delta_s * 12.0)

        if ent_active == 0:
            if game_state == 1:
                rx_int: int = rand() % (MAP_WIDTH - 2) + 1
                ry_int: int = rand() % (MAP_HEIGHT - 2) + 1
                c1: int = get_map(rx_int, ry_int)
                c2: int = get_map(rx_int + 1, ry_int)
                c3: int = get_map(rx_int, ry_int + 1)
                c4: int = get_map(rx_int + 1, ry_int + 1)
                
                if 2 > (c1 + c2 + c3 + c4):
                    dx_s: f64 = (rx_int as f64) - player_x
                    dy_s: f64 = (ry_int as f64) - player_y
                    if (dx_s * dx_s + dy_s * dy_s) > 40.0:
                        r_spawn: int = rand()
                        if 60 > (r_spawn % 100):
                            ent_x = (rx_int as f64) + 0.5
                            ent_y = (ry_int as f64) + 0.5
                            ent_active = 1
                            ent_state = 0
                            ent_timer = 0.0

        ent_dist_approx: f64 = 999.0
        
        if ent_active == 1:
            if game_state == 1:
                if jumpscare_frames == 0:
                    ent_timer = ent_timer + delta_s
                    if ent_timer > 15.0:
                        ent_active = 0
                        ent_state = 0

        if ent_active == 1:
            dx_e: f64 = player_x - ent_x
            dy_e: f64 = player_y - ent_y
            dist_e_sq: f64 = dx_e * dx_e + dy_e * dy_e
            
            abs_dx: f64 = dx_e
            if 0.0 > abs_dx:
                abs_dx = 0.0 - abs_dx
            abs_dy: f64 = dy_e
            if 0.0 > abs_dy:
                abs_dy = 0.0 - abs_dy
            ent_dist_approx = abs_dx + abs_dy
            if 0.01 > ent_dist_approx:
                ent_dist_approx = 0.01
                
            if ent_state == 0:
                if jumpscare_frames == 0:
                    if 100.0 > dist_e_sq:
                        has_los: int = 1
                        ray_steps: int = 20
                        ray_dx: f64 = dx_e / 20.0
                        ray_dy: f64 = dy_e / 20.0
                        cx: f64 = ent_x
                        cy: f64 = ent_y
                        step: int = 0
                        
                        while ray_steps > step:
                            cx = cx + ray_dx
                            cy = cy + ray_dy
                            cx_i: int = cx as int
                            cy_i: int = cy as int
                            if 0 > cx_i:
                                has_los = 0
                                step = ray_steps
                            if cx_i >= MAP_WIDTH:
                                has_los = 0
                                step = ray_steps
                            if 0 > cy_i:
                                has_los = 0
                                step = ray_steps
                            if cy_i >= MAP_HEIGHT:
                                has_los = 0
                                step = ray_steps
                            if has_los == 1:
                                if world_map[cy_i * MAP_WIDTH + cx_i] > 0:
                                    has_los = 0
                                    step = ray_steps 
                            step = step + 1
                        
                        if has_los == 1:
                            ent_state = 1 
                        
            if ent_state == 1:
                if jumpscare_frames == 0:
                    if game_state == 1:
                        if dist_e_sq > 625.0:
                            ent_active = 0
                            ent_state = 0
                        else:
                            dist_f_e: f64 = 1.0 - (ent_dist_approx / 20.0)
                            if 0.0 > dist_f_e:
                                dist_f_e = 0.0
                                
                            ent_speed: f64 = 0.035 + (dist_f_e * 0.03)
                            nx_e: f64 = ent_x + (dx_e / ent_dist_approx) * ent_speed
                            ny_e: f64 = ent_y + (dy_e / ent_dist_approx) * ent_speed
                            
                            if get_map(nx_e as int, ent_y as int) == 0:
                                ent_x = nx_e
                            if get_map(ent_x as int, ny_e as int) == 0:
                                ent_y = ny_e
                            
                            if 0.16 > dist_e_sq:
                                jumpscare_frames = 30
                                m_wi_j: int = 0
                                while 16384 > m_wi_j:
                                    m_t_j: f64 = (m_wi_j as f64) / 8192.0
                                    phase_j: f64 = m_t_j * 800.0
                                    phase_int_j: int = phase_j as int
                                    fract_j: f64 = phase_j - (phase_int_j as f64)
                                    sq_val_j: f64 = -1.0
                                    if 0.5 > fract_j:
                                        sq_val_j = 1.0
                                    r_n_j: int = rand()
                                    val_m: f64 = sq_val_j * 60.0 + ((r_n_j % 255) as f64) * 0.3 + 128.0
                                    if val_m > 255.0:
                                        val_m = 255.0
                                    if 0.0 > val_m:
                                        val_m = 0.0
                                    data_mon[44 + m_wi_j] = val_m as u8
                                    m_wi_j = m_wi_j + 1
                                PlaySoundA(wave_buf_mon_32 as *void, 0 as *void, 13)

        if ent_state == 1:
            if jumpscare_frames == 0:
                if game_state == 1:
                    dist_factor: f64 = 1.0 - (ent_dist_approx / 20.0)
                    if 0.0 > dist_factor:
                        dist_factor = 0.0
                        
                    audio_delay: f64 = 0.8 - (dist_factor * 0.6)
                    
                    ent_audio_timer = ent_audio_timer + delta_s
                    if ent_audio_timer > audio_delay:
                        ent_audio_timer = 0.0
                        
                        if dist_factor > 0.0:
                            vol_mult: f64 = dist_factor * dist_factor * 2.0
                            
                            base_freq: f64 = 100.0 + dist_factor * 100.0
                            r_mod: int = rand() % 3
                            if r_mod == 0:
                                base_freq = base_freq * 0.8
                            if r_mod == 2:
                                base_freq = base_freq * 1.2
                            
                            m_wi: int = 0
                            while 16384 > m_wi:
                                m_t: f64 = (m_wi as f64) / 8192.0
                                phase_s: f64 = m_t * base_freq
                                phase_int_s: int = phase_s as int
                                fract_s: f64 = phase_s - (phase_int_s as f64)
                                sq_val_s: f64 = -1.0
                                if 0.5 > fract_s:
                                    sq_val_s = 1.0
                                sq_val_s = sq_val_s * vol_mult
                                
                                val_m: f64 = sq_val_s * 110.0 + 128.0
                                if val_m > 255.0:
                                    val_m = 255.0
                                if 0.0 > val_m:
                                    val_m = 0.0
                                data_mon[44 + m_wi] = val_m as u8
                                m_wi = m_wi + 1
                            PlaySoundA(wave_buf_mon_32 as *void, 0 as *void, 5)

        tremor_timer = tremor_timer + delta_s * 0.24 
        
        turn_diff: f64 = target_player_a - player_a
        cam_roll: f64 = sin(tremor_timer * 1.2) * 0.015
        if is_moving == 1:
            cam_roll = cam_roll + sin(bob_timer * 0.5) * 0.02

        cam_pitch_f: f64 = sin(tremor_timer * 1.9) * 2.0
        bob_z: f64 = 0.0
        
        if is_moving == 1:
            cam_pitch_f = cam_pitch_f + sin(bob_timer * 1.0) * 4.0
            bob_z = (0.0 - cos(bob_timer)) * bob_amp 

        cam_pitch_f = cam_pitch_f + current_pitch_offset
        
        tape_noise: f64 = ((rand() % 10) as f64 - 5.0) * 0.001
        cam_pitch_f = cam_pitch_f + tape_noise * 5.0
        cam_roll = cam_roll + tape_noise * 2.0 
        
        glClear(16640) 

        glMatrixMode(5889)
        glLoadIdentity()
        
        aspect: f64 = (current_w as f64) / (current_h as f64)
        znear: f64 = 0.02
        zfar: f64 = 55.0
        
        half_fov: f64 = fov * 0.5
        tan_half_fov: f64 = tan(half_fov)
        fh: f64 = znear * tan_half_fov
        fw: f64 = fh * aspect
        glFrustum(0.0 - fw, fw, 0.0 - fh, fh, znear, zfar)

        glMatrixMode(5888)
        glLoadIdentity()

        if flashlight_on == 1:
            glDepthMask(0)
            glEnable(3042)
            glBlendFunc(770, 1)
            glBindTexture(3553, tex_dust)
            
            layer: int = 1
            while 6 > layer:
                dust_a: f64 = 1.0 - ((layer as f64) / 6.0)
                dust_a = dust_a * 0.6
                glColor4d(1.0, 1.0, 1.0, dust_a)
                
                u_shift: f64 = player_x * 0.8 + player_a * 0.5 + (layer as f64) * 0.3
                v_shift: f64 = player_y * 0.8 + current_pitch_offset * 0.01 + tremor_timer * 0.05
                
                z_pos: f64 = 0.0 - (layer as f64) * 1.5
                size: f64 = 1.5 + (layer as f64) * 0.5
                
                glBegin(7)
                glTexCoord2d(0.0 + u_shift, 0.0 + v_shift)
                glVertex3d(0.0 - size, 0.0 - size, z_pos)
                
                glTexCoord2d(2.0 + u_shift, 0.0 + v_shift)
                glVertex3d(size, 0.0 - size, z_pos)
                
                glTexCoord2d(2.0 + u_shift, 2.0 + v_shift)
                glVertex3d(size, size, z_pos)
                
                glTexCoord2d(0.0 + u_shift, 2.0 + v_shift)
                glVertex3d(0.0 - size, size, z_pos)
                glEnd()
                
                layer = layer + 1
                
            glDepthMask(1)
            glDisable(3042)

        cam_pitch_deg: f64 = cam_pitch_f * 0.3
        cam_roll_deg: f64 = cam_roll * 57.2957 + turn_diff * 40.0
        yaw_deg: f64 = player_a * 57.2957
        yaw_deg = yaw_deg + tape_noise * 2.0

        glRotated(cam_pitch_deg, 1.0, 0.0, 0.0)
        glRotated(cam_roll_deg, 0.0, 0.0, 1.0)
        glRotated(180.0 - yaw_deg, 0.0, 1.0, 0.0)

        breathing: f64 = sin(tremor_timer * 2.5) * 0.02
        cam_y: f64 = 0.55 + bob_z + breathing
        
        if game_state == 4:
            if state_timer < 1.0:
                t_f_p: f64 = state_timer / 1.0
                cam_y = 0.9 - 0.7 * (t_f_p * t_f_p * t_f_p)
            else:
                t_f_p: f64 = (state_timer - 1.0) / 2.0
                cam_y = 0.2 + 0.3 * (t_f_p * t_f_p * (3.0 - 2.0 * t_f_p))
                
        if game_state == 5:
            t_f_p: f64 = state_timer / 2.0
            cam_y = 0.5 - 10.0 * (t_f_p * t_f_p)

        glTranslated(0.0 - player_x, 0.0 - cam_y, 0.0 - player_y)

        draw_world(tex_wall, tex_floor, tex_ceil, player_x, player_y, player_a, fov, vis_map, level_type, hole_x, hole_y, flashlight_on)

        if ent_active == 1:
            glEnable(3042)
            glBlendFunc(770, 771) 
            glBindTexture(3553, tex_ent)
            glPushMatrix()
            glTranslated(ent_x, 0.0, ent_y) 
            glRotated(yaw_deg - 180.0, 0.0, 1.0, 0.0)
            
            ent_l: f64 = get_vertex_light(ent_x, ent_y, player_x, player_y, player_a, flashlight_on)
            glColor3d(ent_l, ent_l, ent_l)
            
            glBegin(7)
            glTexCoord2d(0.0, 1.0)
            glVertex3d(-0.6, 0.0, 0.0)
            
            glTexCoord2d(1.0, 1.0)
            glVertex3d(0.6, 0.0, 0.0)
            
            glTexCoord2d(1.0, 0.0)
            glVertex3d(0.6, 2.3, 0.0)
            
            glTexCoord2d(0.0, 0.0)
            glVertex3d(-0.6, 2.3, 0.0)
            glEnd()
            glPopMatrix()
            glDisable(3042)

        cw: f64 = current_w as f64
        ch: f64 = current_h as f64

        glMatrixMode(5889)
        glLoadIdentity()
        glOrtho(0.0, cw, ch, 0.0, -1.0, 1.0)
        glMatrixMode(5888)
        glLoadIdentity()
        glDisable(2929) 
        
        if is_playing == 1:
            glEnable(3042)
            glBlendFunc(770, 771)
            glBindTexture(3553, tex_vig)
            glColor4d(1.0, 1.0, 1.0, 1.0)
            glBegin(7)
            glTexCoord2d(0.0, 0.0)
            glVertex3d(0.0, 0.0, 0.0)
            
            glTexCoord2d(1.0, 0.0)
            glVertex3d(cw, 0.0, 0.0)
            
            glTexCoord2d(1.0, 1.0)
            glVertex3d(cw, ch, 0.0)
            
            glTexCoord2d(0.0, 1.0)
            glVertex3d(0.0, ch, 0.0)
            glEnd()
            glDisable(3042)

            glEnable(3042)
            glBlendFunc(770, 771)
            glBindTexture(3553, tex_vhs)
            shift_x: f64 = ((rand() % 100) as f64) / 100.0
            glColor4d(1.0, 1.0, 1.0, 1.0)
            glBegin(7)
            v_rep: f64 = 15.0
            glTexCoord2d(shift_x, 0.0)
            glVertex3d(0.0, 0.0, 0.0)
            
            glTexCoord2d(1.0 + shift_x, 0.0)
            glVertex3d(cw, 0.0, 0.0)
            
            glTexCoord2d(1.0 + shift_x, v_rep)
            glVertex3d(cw, ch, 0.0)
            
            glTexCoord2d(shift_x, v_rep)
            glVertex3d(0.0, ch, 0.0)
            glEnd()
            glDisable(3042)

            glEnable(3042)
            glDisable(3553)
            glBlendFunc(770, 771)
            glColor4d(0.8, 0.8, 0.8, 0.03)
            glBegin(7)
            band_y: f64 = (0.75 + sin(tremor_timer * 2.0) * 0.1) * ch
            band_h: f64 = 0.15 * ch
            glVertex3d(0.0, band_y, 0.0)
            glVertex3d(cw, band_y, 0.0)
            glVertex3d(cw, band_y + band_h, 0.0)
            glVertex3d(0.0, band_y + band_h, 0.0)
            glEnd()
            glEnable(3553)
            glDisable(3042)
                
            glEnable(3042)
            glDisable(3553)
            glBlendFunc(770, 771)
            glColor4d(0.1, 0.05, 0.0, 0.1)
            glBegin(7)
            glVertex3d(0.0, 0.0, 0.0)
            glVertex3d(cw, 0.0, 0.0)
            glVertex3d(cw, ch, 0.0)
            glVertex3d(0.0, ch, 0.0)
            glEnd()
            glEnable(3553)
            glDisable(3042)
            
            blink_rec: int = (GetTickCount() / 1000) % 2
            if blink_rec == 1:
                draw_text(40.0, 40.0, "REC", 1.0, 0.1, 0.1, 0.9)
            draw_text(cw - 280.0, ch - 80.0, "JUL. 04 1990", 1.0, 1.0, 1.0, 0.8)
            draw_text(cw - 280.0, ch - 50.0, "AM 08:45", 1.0, 1.0, 1.0, 0.8)

        if jumpscare_frames > 0:
            glEnable(3042)
            glBlendFunc(330, 0) 
            glDisable(3553)
            glColor3d(1.0, 1.0, 1.0)
            glBegin(7)
            glVertex3d(0.0, 0.0, 0.0)
            glVertex3d(cw, 0.0, 0.0)
            glVertex3d(cw, ch, 0.0)
            glVertex3d(0.0, ch, 0.0)
            glEnd()
            glBlendFunc(770, 771)
            rnd_op: f64 = ((rand() % 100) as f64) / 100.0
            glColor4d(1.0, 0.0, 0.0, rnd_op)
            glBegin(7)
            glVertex3d(0.0, 0.0, 0.0)
            glVertex3d(cw, 0.0, 0.0)
            glVertex3d(cw, ch, 0.0)
            glVertex3d(0.0, ch, 0.0)
            glEnd()
            glEnable(3553)
            glDisable(3042)

        if is_playing == 0:
            glEnable(3042)
            glDisable(3553)
            glBlendFunc(770, 771)
            glColor4d(0.0, 0.0, 0.0, 0.75)
            glBegin(7)
            glVertex3d(0.0, 0.0, 0.0)
            glVertex3d(cw, 0.0, 0.0)
            glVertex3d(cw, ch, 0.0)
            glVertex3d(0.0, ch, 0.0)
            glEnd()
            glEnable(3553)
            glDisable(3042)

        glEnable(3042)
        glBlendFunc(770, 771)
        
        if is_playing == 1:
            if game_state == 1:
                tutorial_timer = tutorial_timer + delta_s
            if game_state == 6:
                tutorial_timer = 6.0 

            if tutorial_timer < 5.0:
                tut_alpha: f64 = 0.0
                if tutorial_timer < 1.0:
                    tut_alpha = tutorial_timer
                else:
                    if tutorial_timer < 4.0:
                        tut_alpha = 1.0
                    else:
                        tut_alpha = 5.0 - tutorial_timer
                
                draw_text(50.0, ch - 170.0, "W A S D - MOVE", 1.0, 1.0, 1.0, tut_alpha)
                draw_text(50.0, ch - 140.0, "SHIFT - RUN", 1.0, 1.0, 1.0, tut_alpha)
                draw_text(50.0, ch - 110.0, "F - FLASHLIGHT", 1.0, 1.0, 1.0, tut_alpha)
                draw_text(50.0, ch - 80.0, "LMB - ZOOM IN", 1.0, 1.0, 1.0, tut_alpha)
                draw_text(50.0, ch - 50.0, "RMB - ZOOM OUT", 1.0, 1.0, 1.0, tut_alpha)
                
            glDisable(3553)
            glEnable(3042)
            glBlendFunc(770, 771)
            glEnable(3553)
            glDisable(3042)

        if is_playing == 0:
            cen_x: f64 = cw / 2.0
            cen_y: f64 = ch / 2.0

            if game_state == 0:
                draw_text(cen_x - 80.0, cen_y - 85.0, "--- BACKROOMS ---", 1.0, 1.0, 1.0, 1.0)
                draw_text(cen_x - 80.0, cen_y - 35.0, "1. PLAY", 1.0, 1.0, 1.0, 1.0)
                draw_text(cen_x - 80.0, cen_y + 15.0, "2. SETTINGS", 1.0, 1.0, 1.0, 1.0)
                draw_text(cen_x - 80.0, cen_y + 65.0, "3. EXIT", 1.0, 1.0, 1.0, 1.0)
                draw_text(cen_x - 80.0, cen_y + 115.0, "F11. FULLSCREEN", 1.0, 1.0, 1.0, 1.0)

            if game_state == 2:
                draw_text(cen_x - 80.0, cen_y - 160.0, "--- SETTINGS ---", 1.0, 1.0, 1.0, 1.0)
                draw_text(cen_x - 80.0, cen_y - 110.0, "1. SENSITIVITY (CLICK TO CYCLE)", 1.0, 1.0, 1.0, 1.0)
                
                draw_text(cen_x - 80.0, cen_y - 60.0, "2. BIND FORWARD: ", 1.0, 1.0, 1.0, 1.0)
                key_buf[0] = key_fwd
                draw_char(cen_x + 120.0, cen_y - 60.0, key_buf as *void, 1.0, 1.0, 1.0, 1.0)
                
                draw_text(cen_x - 80.0, cen_y - 10.0, "3. BIND BACKWARD: ", 1.0, 1.0, 1.0, 1.0)
                key_buf[0] = key_bck
                draw_char(cen_x + 120.0, cen_y - 10.0, key_buf as *void, 1.0, 1.0, 1.0, 1.0)
                
                draw_text(cen_x - 80.0, cen_y + 40.0, "4. BIND LEFT: ", 1.0, 1.0, 1.0, 1.0)
                key_buf[0] = key_lft
                draw_char(cen_x + 120.0, cen_y + 40.0, key_buf as *void, 1.0, 1.0, 1.0, 1.0)
                
                draw_text(cen_x - 80.0, cen_y + 90.0, "5. BIND RIGHT: ", 1.0, 1.0, 1.0, 1.0)
                key_buf[0] = key_rgt
                draw_char(cen_x + 120.0, cen_y + 90.0, key_buf as *void, 1.0, 1.0, 1.0, 1.0)
                
                draw_text(cen_x - 80.0, cen_y + 140.0, "6. BACK", 1.0, 1.0, 1.0, 1.0)

            if game_state == 3:
                draw_text(cen_x - 80.0, cen_y, "PRESS ANY KEY...", 1.0, 1.0, 1.0, 1.0)

        glDisable(3042)
        glEnable(2929)
        
        SwapBuffers(hdc)

        if jumpscare_frames > 0:
            jumpscare_frames = jumpscare_frames - 1
            if jumpscare_frames == 0:
                is_running = 0

        if jumpscare_frames == 0:
            if can_move == 1:
                next_x: f64 = player_x
                next_y: f64 = player_y

                if GetAsyncKeyState(key_fwd) != 0:
                    next_x = next_x + sin(player_a) * move_speed
                    next_y = next_y + cos(player_a) * move_speed
                if GetAsyncKeyState(key_bck) != 0:
                    next_x = next_x - sin(player_a) * move_speed
                    next_y = next_y - cos(player_a) * move_speed
                if GetAsyncKeyState(key_lft) != 0:
                    next_x = next_x + cos(player_a) * move_speed
                    next_y = next_y - sin(player_a) * move_speed
                if GetAsyncKeyState(key_rgt) != 0:
                    next_x = next_x - cos(player_a) * move_speed
                    next_y = next_y + sin(player_a) * move_speed

                pad: f64 = 0.25
                nx_p: int = (next_x + pad) as int
                nx_m: int = (next_x - pad) as int
                py_p: int = (player_y + pad) as int
                py_m: int = (player_y - pad) as int

                if get_map(nx_p, py_p) == 0:
                    if get_map(nx_p, py_m) == 0:
                        if get_map(nx_m, py_p) == 0:
                            if get_map(nx_m, py_m) == 0:
                                player_x = next_x
                    
                ny_p: int = (next_y + pad) as int
                ny_m: int = (next_y - pad) as int
                px_p: int = (player_x + pad) as int
                px_m: int = (player_x - pad) as int

                if get_map(px_p, ny_p) == 0:
                    if get_map(px_p, ny_m) == 0:
                        if get_map(px_m, ny_p) == 0:
                            if get_map(px_m, ny_m) == 0:
                                player_y = next_y
                
                if game_state == 1:
                    px_int: int = player_x as int
                    py_int: int = player_y as int
                    if px_int == hole_x:
                        if py_int == hole_y:
                            game_state = 5
                            state_timer = 0.0
            
        frame_time: int = GetTickCount() - frame_start
        if 16 > frame_time:
            Sleep(16 - frame_time)
        else:
            Sleep(1)

    PlaySoundA(0 as *void, 0 as *void, 0)
    wglMakeCurrent(0 as *void, 0 as *void)
    
    free(wave_buf_idle_32 as *void)
    free(wave_buf_walk_32 as *void)
    free(wave_buf_run_32 as *void)
    free(wave_buf_mon_32 as *void)
    free(pt)
    free(key_buf)
    free(vis_map)
    
    ShowCursor(1) 
    ReleaseDC(hwnd, hdc)
    ExitProcess(0)
    endofcode