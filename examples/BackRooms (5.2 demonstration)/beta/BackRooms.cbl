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
const WINDOW_W: int = 960
const WINDOW_H: int = 720
const MAP_WIDTH: int = 64
const MAP_HEIGHT: int = 64

world_map: *int = 0 as *int
noise_offset_x: int = 0
noise_offset_y: int = 0

prop_x: *f64 = 0 as *f64
prop_y: *f64 = 0 as *f64
prop_type: *int = 0 as *int
prop_count: int = 0

tex_wall: int = 0
tex_wall_alt: int = 0
tex_mirror: int = 0
tex_wall_2: int = 0
tex_floor: int = 0
tex_floor_2: int = 0
tex_ceil: int = 0
tex_ceil_2: int = 0
tex_ent: int = 0
tex_vig: int = 0
tex_vhs: int = 0
tex_dust: int = 0
tex_chair: int = 0

def noise(x: int, y: int) -> f64:
    nx: int = x + noise_offset_x
    ny: int = y + noise_offset_y
    n: int = nx * 137 + ny * 281
    n = n % 8192
    n = (n * n * 41 + n * 11)
    n = n % 1000
    if 0 > n:
        n = 0 - n
    return (n as f64) / 1000.0

def init_level_1() -> void:
    noise_offset_x = rand() % 10000
    noise_offset_y = rand() % 10000

    i: int = 0
    while 4096 > i:
        world_map[i] = 1
        i = i + 1
        
    y: int = 1
    while 63 > y:
        x: int = 1
        while 63 > x:
            idx: int = y * 64 + x
            b: f64 = noise(x * 4, y * 4) 
            
            if b > 0.45: 
                world_map[idx] = 0
                if noise(x * 12, y * 12) > 0.8:
                    world_map[idx] = 1
            else: 
                world_map[idx] = 1
                if (x % 3) == 0:
                    world_map[idx] = 0
                if (y % 3) == 0:
                    world_map[idx] = 0
                    
            if x <= 1:
                world_map[idx] = 1
            if y <= 1:
                world_map[idx] = 1
            if x >= 62:
                world_map[idx] = 1
            if y >= 62:
                world_map[idx] = 1
            
            if world_map[idx] == 1:
                rw: int = rand() % 100
                if rw > 98:
                    world_map[idx] = 6
                elif rw > 85:
                    world_map[idx] = 7
            else:
                n_elev: f64 = noise(x * 25, y * 25)
                if n_elev > 0.94:
                    world_map[idx] = 5
                elif 0.06 > n_elev:
                    world_map[idx] = 4
                    
            x = x + 1
        y = y + 1

    world_map[2 * 64 + 2] = 0
    world_map[2 * 64 + 3] = 0
    world_map[3 * 64 + 2] = 0
    world_map[3 * 64 + 3] = 0

    prop_count = 0
    y_p: int = 1
    while 63 > y_p:
        x_p: int = 1
        while 63 > x_p:
            if world_map[y_p * 64 + x_p] == 0:
                pseudo_rnd: int = (x_p * 37 + y_p * 113) % 100
                if pseudo_rnd > 97:
                    if 300 > prop_count:
                        prop_x[prop_count] = (x_p as f64) + 0.5
                        prop_y[prop_count] = (y_p as f64) + 0.5
                        prop_type[prop_count] = 1 
                        prop_count = prop_count + 1
            x_p = x_p + 1
        y_p = y_p + 1

def init_level_2() -> void:
    noise_offset_x = rand() % 10000
    noise_offset_y = rand() % 10000

    prop_count = 0 

    i: int = 0
    while 4096 > i:
        world_map[i] = 1
        i = i + 1
        
    y: int = 1
    while 63 > y:
        x: int = 1
        while 63 > x:
            idx: int = y * 64 + x
            n1: f64 = noise(x * 3, y * 3) 
            n2: f64 = noise(x * 7, y * 7)
            
            world_map[idx] = 2 
            
            if n1 > 0.45:
                world_map[idx] = 3 
            else:
                world_map[idx] = 0 
                
            is_macro: int = 0
            if (x % 8) == 2:
                is_macro = 1
                world_map[idx] = 3
            if (y % 8) == 2:
                is_macro = 1
                world_map[idx] = 3
                
            if n2 > 0.85:
                if is_macro == 0:
                    world_map[idx] = 1 
                
            x = x + 1
        y = y + 1
        
    y = 1
    while 5 > y:
        x = 1
        while 5 > x:
            world_map[y * 64 + x] = 3
            x = x + 1
        y = y + 1
        
    y = 0
    while 64 > y:
        world_map[y * 64 + 0] = 1
        world_map[y * 64 + 63] = 1
        world_map[0 * 64 + y] = 1
        world_map[63 * 64 + y] = 1
        y = y + 1

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

def get_tile_h(x: int, y: int, level: int) -> f64:
    if 0 > x:
        return 1.0
    if x >= MAP_WIDTH:
        return 1.0
    if 0 > y:
        return 1.0
    if y >= MAP_HEIGHT:
        return 1.0
    
    val: int = world_map[y * MAP_WIDTH + x]
    
    if level == 0:
        if val == 1:
            return 1.5
        if val == 6:
            return 1.5
        if val == 7:
            return 1.5
        if val == 4:
            return -0.4
        if val == 5:
            return 0.35
        return 0.0
    
    if val == 1:
        return 1.5
    if val == 3:
        return 0.1
    if val == 0:
        return -1.0 
    return 1.0

def can_walk(cx: int, cy: int, nx: int, ny: int, lvl: int) -> int:
    if 0 > nx:
        return 0
    if nx >= MAP_WIDTH:
        return 0
    if 0 > ny:
        return 0
    if ny >= MAP_HEIGHT:
        return 0
        
    val: int = world_map[ny * MAP_WIDTH + nx]
    if val == 1:
        return 0
    if val == 6:
        return 0
    if val == 7:
        return 0
    return 1

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

def create_texture(type_id: int) -> int:
    tex_id: *int = malloc(4) as *int
    glGenTextures(1, tex_id)
    glBindTexture(3553, tex_id[0]) 
    glTexParameteri(3553, 10241, 9728) 
    glTexParameteri(3553, 10240, 9728)
    glTexParameteri(3553, 10242, 10497) 
    glTexParameteri(3553, 10243, 10497)

    buf: *int = malloc(16384) as *int
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
                if 6 > y:
                    col_r = 50.0
                    col_g = 30.0
                    col_b = 10.0
                r = col_r as int
                g = col_g as int
                b = col_b as int

            if type_id == 12:
                col_r = 170.0
                col_g = 140.0
                col_b = 50.0
                if (x % 16) > 14:
                    col_r = 140.0
                    col_g = 110.0
                    col_b = 30.0
                n_dmg: f64 = noise(x * 12, y * 8)
                if n_dmg > 0.6:
                    col_r = col_r * 0.5
                    col_g = col_g * 0.5
                    col_b = col_b * 0.4
                if 6 > y:
                    col_r = 40.0
                    col_g = 20.0
                    col_b = 5.0
                r = col_r as int
                g = col_g as int
                b = col_b as int

            if type_id == 14:
                r = 160
                g = 180
                b = 200
                a = 90 
                n_m: f64 = noise(x * 20, y * 20)
                r = r + (n_m * 20.0) as int
                g = g + (n_m * 20.0) as int
                b = b + (n_m * 20.0) as int
                if noise(x * 100, y * 100) > 0.9:
                    if noise(x * 5, y * 5) > 0.5:
                        r = 60
                        g = 60
                        b = 60
                        a = 180

            if type_id == 13:
                r = 70
                g = 40
                b = 15
                a = 255
                n_w: f64 = noise(x * 50, y * 10)
                r = r + (n_w * 20.0) as int
                g = g + (n_w * 10.0) as int
            
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
                r = 0
                g = 0
                b = 0
                a = 0

            if type_id == 5:
                dx_v: f64 = ((x as f64) - 32.0) / 32.0
                dy_v: f64 = ((y as f64) - 32.0) / 32.0
                dist_sq_v: f64 = dx_v * dx_v + dy_v * dy_v
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
                    
            if type_id == 8: 
                r = 210
                g = 230
                b = 240
                if (x % 16) < 1:
                    r = 150
                    g = 170
                    b = 180
                elif (y % 16) < 1:
                    r = 150
                    g = 170
                    b = 180
                else:
                    grad: f64 = ((x % 16) as f64) / 16.0
                    r = r + (grad * 20.0) as int
                    g = g + (grad * 20.0) as int
                    b = b + (grad * 20.0) as int

            if type_id == 9: 
                r = 140
                g = 180
                b = 210
                if (x % 16) < 1:
                    r = 90
                    g = 130
                    b = 160
                elif (y % 16) < 1:
                    r = 90
                    g = 130
                    b = 160
                else:
                    grad: f64 = ((x % 16) as f64) / 16.0
                    r = r + (grad * 20.0) as int
                    g = g + (grad * 20.0) as int
                    b = b + (grad * 20.0) as int
                        
            if type_id == 11:
                r = 250
                g = 250
                b = 250
                if (x % 32) < 2:
                    r = 200
                    g = 200
                    b = 200
                elif (y % 32) < 2:
                    r = 200
                    g = 200
                    b = 200
                else:
                    grad_b: f64 = ((x % 32) as f64) / 32.0
                    r = r - (grad_b * 15.0) as int
                    g = g - (grad_b * 15.0) as int
                    b = b - (grad_b * 15.0) as int
                    
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

def draw_text_3d(x: f64, y: f64, z: f64, text: str, r: f64, g: f64, b: f64, a: f64) -> void:
    glDisable(3553)
    glColor4d(r, g, b, a)
    glRasterPos3d(x, y, z)
    glListBase(1000)
    glCallLists(text.length, 5121, text.data as *void)
    glEnable(3553)

def get_vertex_light(vx: f64, vy: f64, px: f64, py: f64, pa: f64, flash_on: int, level_type: int) -> f64:
    dx_p: f64 = vx - px
    dy_p: f64 = vy - py
    dist_p_sq: f64 = dx_p * dx_p + dy_p * dy_p
    
    vx_i: int = vx as int
    vy_i: int = vy as int
    curr_h: f64 = get_tile_h(vx_i, vy_i, level_type)
    h_l: f64 = get_tile_h(vx_i - 1, vy_i, level_type)
    h_u: f64 = get_tile_h(vx_i, vy_i - 1, level_type)
    h_ul: f64 = get_tile_h(vx_i - 1, vy_i - 1, level_type)
    
    if level_type == 2:
        fade_lvl2: f64 = 1.0 - (dist_p_sq / 1200.0)
        if 0.0 > fade_lvl2:
            fade_lvl2 = 0.0
            
        dir_shadow: f64 = 1.0
        if h_l > curr_h:
            dir_shadow = dir_shadow - 0.25
        if h_u > curr_h:
            dir_shadow = dir_shadow - 0.25
        if h_ul > curr_h:
            dir_shadow = dir_shadow - 0.15
            
        if 0.3 > dir_shadow:
            dir_shadow = 0.3
            
        depth_dark: f64 = 1.0
        if 0.0 > curr_h:
            depth_dark = 0.7

        i_l2: f64 = (dir_shadow * depth_dark) * 0.9 + fade_lvl2 * 0.1
        
        if curr_h > 0.0:
            c_time: f64 = (clock() as f64) * 0.002
            i_l2 = i_l2 + sin(c_time + vx * 3.0 + vy * 3.0) * 0.06
            
        if i_l2 > 1.0:
            i_l2 = 1.0
        return i_l2

    lx_int: int = (vx / 2.0) as int
    ly_int: int = (vy / 2.0) as int
    
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
        time_s: int = clock()
        blink: f64 = sin((time_s as f64) * 0.015)
        if blink > 0.0:
            lamp_power = 0.0
        
    illum: f64 = 0.12 + lamp_power / (dist_sq_l * 1.2 + 1.0)
    
    fade: f64 = 1.0 - (dist_p_sq / 80.0) 
    if 0.0 > fade:
        fade = 0.0
        
    flash_illum: f64 = 0.0
    
    if flash_on == 1:
        if 144.0 > dist_p_sq: 
            dist_p: f64 = sqrt(dist_p_sq)
            if dist_p > 0.1:
                nx: f64 = dx_p / dist_p
                ny: f64 = dy_p / dist_p
                p_dir_x: f64 = sin(pa)
                p_dir_y: f64 = cos(pa)
                
                dot: f64 = nx * p_dir_x + ny * p_dir_y
                if dot > 0.65: 
                    spot: f64 = 1.0 - (dist_p / 10.0)
                    if spot > 0.0:
                        edge: f64 = (dot - 0.65) * 3.5
                        if edge > 1.0:
                            edge = 1.0
                        edge = edge * edge 
                        flash_illum = spot * edge * 0.8
                            
    illum = (illum * fade) + flash_illum
    illum = illum * 1.2
    illum = illum * illum * 1.8
    
    if level_type == 0:
        ao: f64 = 1.0
        if h_l > curr_h:
            ao = ao - 0.25
        if h_u > curr_h:
            ao = ao - 0.25
        if 0.4 > ao:
            ao = 0.4
        illum = illum * ao
        
    if illum > 1.0:
        illum = 1.0
    return illum

def calc_vis(px: f64, py: f64, vis_map: *int) -> void:
    i: int = 0
    while 4096 > i:
        vis_map[i] = 0
        i = i + 1

    y_v: int = 0
    while MAP_HEIGHT > y_v:
        x_v: int = 0
        while MAP_WIDTH > x_v:
            dx_v: f64 = (x_v as f64) + 0.5 - px
            dy_v: f64 = (y_v as f64) + 0.5 - py
            if 400.0 > (dx_v * dx_v + dy_v * dy_v):
                vis_map[y_v * MAP_WIDTH + x_v] = 1
            x_v = x_v + 1
        y_v = y_v + 1

def draw_world(px: f64, py: f64, pa: f64, fov: f64, vis_map: *int, level_type: int, hole_x: int, hole_y: int, flash_on: int, is_reflection: int, clip_axis: int, clip_dir: int, plane_coord: f64) -> void:
    y_d: int = 0
    x_d: int = 0
    idx_w: int = 0
    xf: f64 = 0.0
    yf: f64 = 0.0
    curr_h: f64 = 0.0
    n_h: f64 = 0.0

    if level_type == 2:
        glBindTexture(3553, tex_floor_2)
    else:
        glBindTexture(3553, tex_floor)
        
    glBegin(7)
    y_d = 0
    while MAP_HEIGHT > y_d:
        x_d = 0
        while MAP_WIDTH > x_d:
            idx_w = y_d * MAP_WIDTH + x_d
            if vis_map[idx_w] == 1:
                do_draw: int = 1
                if is_reflection == 1:
                    if clip_axis == 0:
                        if clip_dir == 1:
                            if plane_coord > (x_d as f64) + 1.1:
                                do_draw = 0
                        else:
                            if (x_d as f64) - 0.1 > plane_coord:
                                do_draw = 0
                    else:
                        if clip_dir == 1:
                            if plane_coord > (y_d as f64) + 1.1:
                                do_draw = 0
                        else:
                            if (y_d as f64) - 0.1 > plane_coord:
                                do_draw = 0
                if do_draw == 1:
                    val_m: int = world_map[idx_w]
                    if val_m != 1:
                        if val_m != 6:
                            if val_m != 7:
                                xf = x_d as f64
                                yf = y_d as f64
                                curr_h = get_tile_h(x_d, y_d, level_type)
                                
                                l00: f64 = get_vertex_light(xf, yf, px, py, pa, flash_on, level_type)
                                l10: f64 = get_vertex_light(xf + 1.0, yf, px, py, pa, flash_on, level_type)
                                l11: f64 = get_vertex_light(xf + 1.0, yf + 1.0, px, py, pa, flash_on, level_type)
                                l01: f64 = get_vertex_light(xf, yf + 1.0, px, py, pa, flash_on, level_type)
                                
                                glColor3d(l00, l00, l00)
                                glTexCoord2d(xf, yf)
                                glVertex3d(xf, curr_h, yf)
                                
                                glColor3d(l10, l10, l10)
                                glTexCoord2d(xf + 1.0, yf)
                                glVertex3d(xf + 1.0, curr_h, yf)
                                
                                glColor3d(l11, l11, l11)
                                glTexCoord2d(xf + 1.0, yf + 1.0)
                                glVertex3d(xf + 1.0, curr_h, yf + 1.0)
                                
                                glColor3d(l01, l01, l01)
                                glTexCoord2d(xf, yf + 1.0)
                                glVertex3d(xf, curr_h, yf + 1.0)
            x_d = x_d + 1
        y_d = y_d + 1
    glEnd()

    if level_type == 2:
        glBindTexture(3553, tex_ceil_2)
    else:
        glBindTexture(3553, tex_ceil)
        
    glBegin(7)
    y_d = 0
    while MAP_HEIGHT > y_d:
        x_d = 0
        while MAP_WIDTH > x_d:
            idx_w = y_d * MAP_WIDTH + x_d
            if vis_map[idx_w] == 1:
                do_draw = 1
                if is_reflection == 1:
                    if clip_axis == 0:
                        if clip_dir == 1:
                            if plane_coord > (x_d as f64) + 1.1:
                                do_draw = 0
                        else:
                            if (x_d as f64) - 0.1 > plane_coord:
                                do_draw = 0
                    else:
                        if clip_dir == 1:
                            if plane_coord > (y_d as f64) + 1.1:
                                do_draw = 0
                        else:
                            if (y_d as f64) - 0.1 > plane_coord:
                                do_draw = 0
                if do_draw == 1:
                    if world_map[idx_w] != 1:
                        if world_map[idx_w] != 6:
                            if world_map[idx_w] != 7:
                                xf = x_d as f64
                                yf = y_d as f64
                                
                                l00_c: f64 = get_vertex_light(xf, yf, px, py, pa, flash_on, level_type)
                                l10_c: f64 = get_vertex_light(xf + 1.0, yf, px, py, pa, flash_on, level_type)
                                l11_c: f64 = get_vertex_light(xf + 1.0, yf + 1.0, px, py, pa, flash_on, level_type)
                                l01_c: f64 = get_vertex_light(xf, yf + 1.0, px, py, pa, flash_on, level_type)
                                
                                ceil_h: f64 = 1.5
                                
                                glColor3d(l00_c, l00_c, l00_c)
                                glTexCoord2d(xf / 2.0, yf / 2.0)
                                glVertex3d(xf, ceil_h, yf)
                                
                                glColor3d(l10_c, l10_c, l10_c)
                                glTexCoord2d((xf + 1.0) / 2.0, yf / 2.0)
                                glVertex3d(xf + 1.0, ceil_h, yf)
                                
                                glColor3d(l11_c, l11_c, l11_c)
                                glTexCoord2d((xf + 1.0) / 2.0, (yf + 1.0) / 2.0)
                                glVertex3d(xf + 1.0, ceil_h, yf + 1.0)
                                
                                glColor3d(l01_c, l01_c, l01_c)
                                glTexCoord2d(xf / 2.0, (yf + 1.0) / 2.0)
                                glVertex3d(xf, ceil_h, yf + 1.0)
            x_d = x_d + 1
        y_d = y_d + 1
    glEnd()

    pass_i: int = 1
    while 3 > pass_i:
        is_valid: int = 1
        if level_type == 2:
            if pass_i > 1:
                is_valid = 0
            else:
                glBindTexture(3553, tex_wall_2)
        else:
            if pass_i == 1:
                glBindTexture(3553, tex_wall)
            elif pass_i == 2:
                glBindTexture(3553, tex_wall_alt)

        if is_valid == 1:
            glBegin(7)
            y_d = 0
            while MAP_HEIGHT > y_d:
                x_d = 0
                while MAP_WIDTH > x_d:
                    idx_w = y_d * MAP_WIDTH + x_d
                    if vis_map[idx_w] == 1:
                        do_draw = 1
                        if is_reflection == 1:
                            if clip_axis == 0:
                                if clip_dir == 1:
                                    if plane_coord > (x_d as f64) + 1.1:
                                        do_draw = 0
                                else:
                                    if (x_d as f64) - 0.1 > plane_coord:
                                        do_draw = 0
                            else:
                                if clip_dir == 1:
                                    if plane_coord > (y_d as f64) + 1.1:
                                        do_draw = 0
                                else:
                                    if (y_d as f64) - 0.1 > plane_coord:
                                        do_draw = 0
                        if do_draw == 1:
                            w_type: int = world_map[idx_w]
                            my_pass: int = 0
                            if level_type == 2:
                                my_pass = 1
                            else:
                                if pass_i == 1:
                                    if w_type != 7:
                                        my_pass = 1
                                if pass_i == 2:
                                    if w_type == 7:
                                        my_pass = 1
                            if my_pass == 1:
                                xf = x_d as f64
                                yf = y_d as f64
                                curr_h = get_tile_h(x_d, y_d, level_type)
                                
                                n_h = get_tile_h(x_d, y_d - 1, level_type)
                                if curr_h > n_h:
                                    l0_w: f64 = get_vertex_light(xf, yf, px, py, pa, flash_on, level_type)
                                    l1_w: f64 = get_vertex_light(xf + 1.0, yf, px, py, pa, flash_on, level_type)
                                    glColor3d(l0_w, l0_w, l0_w)
                                    glTexCoord2d(0.0, curr_h)
                                    glVertex3d(xf, curr_h, yf)
                                    glColor3d(l1_w, l1_w, l1_w)
                                    glTexCoord2d(1.0, curr_h)
                                    glVertex3d(xf + 1.0, curr_h, yf)
                                    glColor3d(l1_w, l1_w, l1_w)
                                    glTexCoord2d(1.0, n_h)
                                    glVertex3d(xf + 1.0, n_h, yf)
                                    glColor3d(l0_w, l0_w, l0_w)
                                    glTexCoord2d(0.0, n_h)
                                    glVertex3d(xf, n_h, yf)

                                n_h = get_tile_h(x_d, y_d + 1, level_type)
                                if curr_h > n_h:
                                    l0_w = get_vertex_light(xf + 1.0, yf + 1.0, px, py, pa, flash_on, level_type)
                                    l1_w = get_vertex_light(xf, yf + 1.0, px, py, pa, flash_on, level_type)
                                    glColor3d(l0_w, l0_w, l0_w)
                                    glTexCoord2d(0.0, curr_h)
                                    glVertex3d(xf + 1.0, curr_h, yf + 1.0)
                                    glColor3d(l1_w, l1_w, l1_w)
                                    glTexCoord2d(1.0, curr_h)
                                    glVertex3d(xf, curr_h, yf + 1.0)
                                    glColor3d(l1_w, l1_w, l1_w)
                                    glTexCoord2d(1.0, n_h)
                                    glVertex3d(xf, n_h, yf + 1.0)
                                    glColor3d(l0_w, l0_w, l0_w)
                                    glTexCoord2d(0.0, n_h)
                                    glVertex3d(xf + 1.0, n_h, yf + 1.0)

                                n_h = get_tile_h(x_d - 1, y_d, level_type)
                                if curr_h > n_h:
                                    l0_w = get_vertex_light(xf, yf + 1.0, px, py, pa, flash_on, level_type)
                                    l1_w = get_vertex_light(xf, yf, px, py, pa, flash_on, level_type)
                                    glColor3d(l0_w, l0_w, l0_w)
                                    glTexCoord2d(0.0, curr_h)
                                    glVertex3d(xf, curr_h, yf + 1.0)
                                    glColor3d(l1_w, l1_w, l1_w)
                                    glTexCoord2d(1.0, curr_h)
                                    glVertex3d(xf, curr_h, yf)
                                    glColor3d(l1_w, l1_w, l1_w)
                                    glTexCoord2d(1.0, n_h)
                                    glVertex3d(xf, n_h, yf)
                                    glColor3d(l0_w, l0_w, l0_w)
                                    glTexCoord2d(0.0, n_h)
                                    glVertex3d(xf, n_h, yf + 1.0)

                                n_h = get_tile_h(x_d + 1, y_d, level_type)
                                if curr_h > n_h:
                                    l0_w = get_vertex_light(xf + 1.0, yf, px, py, pa, flash_on, level_type)
                                    l1_w = get_vertex_light(xf + 1.0, yf + 1.0, px, py, pa, flash_on, level_type)
                                    glColor3d(l0_w, l0_w, l0_w)
                                    glTexCoord2d(0.0, curr_h)
                                    glVertex3d(xf + 1.0, curr_h, yf)
                                    glColor3d(l1_w, l1_w, l1_w)
                                    glTexCoord2d(1.0, curr_h)
                                    glVertex3d(xf + 1.0, curr_h, yf + 1.0)
                                    glColor3d(l1_w, l1_w, l1_w)
                                    glTexCoord2d(1.0, n_h)
                                    glVertex3d(xf + 1.0, n_h, yf + 1.0)
                                    glColor3d(l0_w, l0_w, l0_w)
                                    glTexCoord2d(0.0, n_h)
                                    glVertex3d(xf + 1.0, n_h, yf)
                    x_d = x_d + 1
                y_d = y_d + 1
            glEnd()
        pass_i = pass_i + 1

    if level_type == 0:
        glDisable(3553)
        glBegin(7)
        hxf: f64 = hole_x as f64
        hyf: f64 = hole_y as f64
        hole_h: f64 = get_tile_h(hole_x, hole_y, 0) + 0.01
        
        glColor3d(0.0, 0.0, 0.0)
        glVertex3d(hxf, hole_h, hyf)
        glVertex3d(hxf + 1.0, hole_h, hyf)
        glVertex3d(hxf + 1.0, hole_h, hyf + 1.0)
        glVertex3d(hxf, hole_h, hyf + 1.0)
        glVertex3d(hxf, hole_h, hyf)
        glVertex3d(hxf + 1.0, hole_h, hyf)
        glVertex3d(hxf + 1.0, -10.0, hyf)
        glVertex3d(hxf, -10.0, hyf)
        
        glVertex3d(hxf + 1.0, hole_h, hyf)
        glVertex3d(hxf + 1.0, hole_h, hyf + 1.0)
        glVertex3d(hxf + 1.0, -10.0, hyf + 1.0)
        glVertex3d(hxf + 1.0, -10.0, hyf)
        
        glVertex3d(hxf + 1.0, hole_h, hyf + 1.0)
        glVertex3d(hxf, hole_h, hyf + 1.0)
        glVertex3d(hxf, -10.0, hyf + 1.0)
        glVertex3d(hxf + 1.0, -10.0, hyf + 1.0)
        
        glVertex3d(hxf, hole_h, hyf + 1.0)
        glVertex3d(hxf, hole_h, hyf)
        glVertex3d(hxf, -10.0, hyf)
        glVertex3d(hxf, -10.0, hyf + 1.0)
        
        glEnd()
        glEnable(3553)
        
    if level_type == 2:
        glEnable(3042)
        glBlendFunc(770, 771)
        glDisable(3553)
        
        c_time: f64 = (clock() as f64) * 0.002
        
        glBegin(7)
        wy: int = 0
        while MAP_HEIGHT > wy:
            wx: int = 0
            while MAP_WIDTH > wx:
                if world_map[wy * MAP_WIDTH + wx] == 0:
                    wxf: f64 = wx as f64
                    wyf: f64 = wy as f64
                    
                    z00: f64 = -0.15 + sin(c_time + wxf*0.8 + wyf*0.5)*0.04
                    z10: f64 = -0.15 + sin(c_time + (wxf+1.0)*0.8 + wyf*0.5)*0.04
                    z11: f64 = -0.15 + sin(c_time + (wxf+1.0)*0.8 + (wyf+1.0)*0.5)*0.04
                    z01: f64 = -0.15 + sin(c_time + wxf*0.8 + (wyf+1.0)*0.5)*0.04
                    
                    c00: f64 = (z00 + 0.18) * 8.0
                    c10: f64 = (z10 + 0.18) * 8.0
                    c11: f64 = (z11 + 0.18) * 8.0
                    c01: f64 = (z01 + 0.18) * 8.0
                    
                    glColor4d(0.0, 0.4 * c00, 0.7 * c00, 0.6)
                    glVertex3d(wxf, z00, wyf)
                    
                    glColor4d(0.0, 0.4 * c10, 0.7 * c10, 0.6)
                    glVertex3d(wxf + 1.0, z10, wyf)
                    
                    glColor4d(0.0, 0.4 * c11, 0.7 * c11, 0.6)
                    glVertex3d(wxf + 1.0, z11, wyf + 1.0)
                    
                    glColor4d(0.0, 0.4 * c01, 0.7 * c01, 0.6)
                    glVertex3d(wxf, z01, wyf + 1.0)
                wx = wx + 1
            wy = wy + 1
        glEnd()
        
        glEnable(3553)
        glDisable(3042)

def draw_props(px: f64, py: f64, pa: f64, flash_on: int, level_type: int, ent_active: int, ent_x: f64, ent_y: f64, yaw_deg: f64, is_reflection: int, clip_axis: int, clip_dir: int, plane_coord: f64) -> void:
    if level_type == 0:
        glEnable(3042)
        glBlendFunc(770, 771)
        glBindTexture(3553, tex_chair)
        
        i: int = 0
        while prop_count > i:
            px_c: f64 = prop_x[i]
            py_c: f64 = prop_y[i]
            
            do_draw: int = 1
            if is_reflection == 1:
                if clip_axis == 0:
                    if clip_dir == 1:
                        if plane_coord > px_c:
                            do_draw = 0
                    else:
                        if px_c > plane_coord:
                            do_draw = 0
                else:
                    if clip_dir == 1:
                        if plane_coord > py_c:
                            do_draw = 0
                    else:
                        if py_c > plane_coord:
                            do_draw = 0
                            
            if do_draw == 1:
                dx_c: f64 = px_c - px
                dy_c: f64 = py_c - py
                dist_c_sq: f64 = dx_c * dx_c + dy_c * dy_c
                if 200.0 > dist_c_sq:
                    glPushMatrix()
                    glTranslated(px_c, get_tile_h(px_c as int, py_c as int, 0), py_c)
                    
                    l_c: f64 = get_vertex_light(px_c, py_c, px, py, pa, flash_on, 0)
                    glColor4d(l_c, l_c, l_c, 1.0)
                    
                    glBegin(7)
                    glTexCoord2d(0.0, 0.0)
                    glVertex3d(-0.15, 0.3, -0.15)
                    glTexCoord2d(1.0, 0.0)
                    glVertex3d(0.15, 0.3, -0.15)
                    glTexCoord2d(1.0, 1.0)
                    glVertex3d(0.15, 0.3, 0.15)
                    glTexCoord2d(0.0, 1.0)
                    glVertex3d(-0.15, 0.3, 0.15)
                    
                    glTexCoord2d(0.0, 0.0)
                    glVertex3d(-0.15, 0.6, -0.15)
                    glTexCoord2d(1.0, 0.0)
                    glVertex3d(0.15, 0.6, -0.15)
                    glTexCoord2d(1.0, 1.0)
                    glVertex3d(0.15, 0.3, -0.15)
                    glTexCoord2d(0.0, 1.0)
                    glVertex3d(-0.15, 0.3, -0.15)
                    
                    glTexCoord2d(0.0, 0.0)
                    glVertex3d(-0.15, 0.3, -0.15)
                    glTexCoord2d(1.0, 0.0)
                    glVertex3d(0.15, 0.3, 0.15)
                    glTexCoord2d(1.0, 1.0)
                    glVertex3d(0.15, 0.0, 0.15)
                    glTexCoord2d(0.0, 1.0)
                    glVertex3d(-0.15, 0.0, -0.15)
                    
                    glTexCoord2d(0.0, 0.0)
                    glVertex3d(0.15, 0.3, -0.15)
                    glTexCoord2d(1.0, 0.0)
                    glVertex3d(-0.15, 0.3, 0.15)
                    glTexCoord2d(1.0, 1.0)
                    glVertex3d(-0.15, 0.0, 0.15)
                    glTexCoord2d(0.0, 1.0)
                    glVertex3d(0.15, 0.0, -0.15)
                    glEnd()
                    
                    glPopMatrix()
            i = i + 1
        glDisable(3042)

    if ent_active == 1:
        do_draw_ent: int = 1
        if is_reflection == 1:
            if clip_axis == 0:
                if clip_dir == 1:
                    if plane_coord > ent_x:
                        do_draw_ent = 0
                else:
                    if ent_x > plane_coord:
                        do_draw_ent = 0
            else:
                if clip_dir == 1:
                    if plane_coord > ent_y:
                        do_draw_ent = 0
                else:
                    if ent_y > plane_coord:
                        do_draw_ent = 0
                        
        if do_draw_ent == 1:
            glEnable(3042)
            glBlendFunc(770, 771) 
            glDisable(3553)
            
            glPushMatrix()
            ent_floor_h: f64 = get_tile_h(ent_x as int, ent_y as int, level_type)
            glTranslated(ent_x, ent_floor_h, ent_y) 
            glRotated(yaw_deg - 180.0, 0.0, 1.0, 0.0)
            
            ent_l: f64 = get_vertex_light(ent_x, ent_y, px, py, pa, flash_on, level_type)
            glColor4d(0.0, 0.0, 0.0, 1.0) 
            
            jit: f64 = sin((clock() as f64) * 0.05) * 0.02
            
            glBegin(7)
            glVertex3d(-0.05 + jit, 0.0, 0.0)
            glVertex3d(0.05 + jit, 0.0, 0.0)
            glVertex3d(0.05 - jit, 0.5, 0.0)
            glVertex3d(-0.05 - jit, 0.5, 0.0)
            
            glVertex3d(-0.15 + jit, 0.5, 0.0)
            glVertex3d(0.15 + jit, 0.5, 0.0)
            glVertex3d(0.15 - jit, 0.7, 0.0)
            glVertex3d(-0.15 - jit, 0.7, 0.0)
            
            glVertex3d(-0.25, 0.2, 0.0)
            glVertex3d(-0.15, 0.2, 0.0)
            glVertex3d(-0.15 + jit, 0.7, 0.0)
            glVertex3d(-0.25 + jit, 0.7, 0.0)
            
            glVertex3d(0.15, 0.2, 0.0)
            glVertex3d(0.25, 0.2, 0.0)
            glVertex3d(0.25 - jit, 0.7, 0.0)
            glVertex3d(0.15 - jit, 0.7, 0.0)
            
            glVertex3d(-0.1 - jit, 0.7, 0.0)
            glVertex3d(0.1 + jit, 0.7, 0.0)
            glVertex3d(0.1 - jit, 0.9, 0.0)
            glVertex3d(-0.1 + jit, 0.9, 0.0)
            glEnd()
            
            glPopMatrix()
            glEnable(3553)
            glDisable(3042)

def draw_mirrors(px: f64, py: f64, pa: f64, flash_on: int, level_type: int, vis_map: *int, mx: int, my: int) -> void:
    glBegin(7)
    y_d: int = 0
    while MAP_HEIGHT > y_d:
        x_d: int = 0
        while MAP_WIDTH > x_d:
            idx_w: int = y_d * MAP_WIDTH + x_d
            if vis_map[idx_w] == 1:
                w_type: int = world_map[idx_w]
                if w_type == 6:
                    if x_d == mx:
                        if y_d == my:
                            xf: f64 = x_d as f64
                            yf: f64 = y_d as f64
                            curr_h: f64 = get_tile_h(x_d, y_d, level_type)
                            
                            n_h: f64 = get_tile_h(x_d, y_d - 1, level_type)
                            if curr_h > n_h:
                                vz1: f64 = curr_h - 0.4
                                vz2: f64 = n_h + 0.1
                                vx1: f64 = xf + 0.2
                                vx2: f64 = xf + 0.8
                                vyf: f64 = yf - 0.01
                                l0_w: f64 = get_vertex_light(vx1, vyf, px, py, pa, flash_on, level_type)
                                l1_w: f64 = get_vertex_light(vx2, vyf, px, py, pa, flash_on, level_type)
                                glColor3d(l0_w, l0_w, l0_w)
                                glTexCoord2d(0.0, vz1)
                                glVertex3d(vx1, vz1, vyf)
                                glColor3d(l1_w, l1_w, l1_w)
                                glTexCoord2d(1.0, vz1)
                                glVertex3d(vx2, vz1, vyf)
                                glColor3d(l1_w, l1_w, l1_w)
                                glTexCoord2d(1.0, vz2)
                                glVertex3d(vx2, vz2, vyf)
                                glColor3d(l0_w, l0_w, l0_w)
                                glTexCoord2d(0.0, vz2)
                                glVertex3d(vx1, vz2, vyf)

                            n_h = get_tile_h(x_d, y_d + 1, level_type)
                            if curr_h > n_h:
                                vz1 = curr_h - 0.4
                                vz2 = n_h + 0.1
                                vx1 = xf + 0.8
                                vx2 = xf + 0.2
                                vyf = yf + 1.01
                                l0_w = get_vertex_light(vx1, vyf, px, py, pa, flash_on, level_type)
                                l1_w = get_vertex_light(vx2, vyf, px, py, pa, flash_on, level_type)
                                glColor3d(l0_w, l0_w, l0_w)
                                glTexCoord2d(0.0, vz1)
                                glVertex3d(vx1, vz1, vyf)
                                glColor3d(l1_w, l1_w, l1_w)
                                glTexCoord2d(1.0, vz1)
                                glVertex3d(vx2, vz1, vyf)
                                glColor3d(l1_w, l1_w, l1_w)
                                glTexCoord2d(1.0, vz2)
                                glVertex3d(vx2, vz2, vyf)
                                glColor3d(l0_w, l0_w, l0_w)
                                glTexCoord2d(0.0, vz2)
                                glVertex3d(vx1, vz2, vyf)

                            n_h = get_tile_h(x_d - 1, y_d, level_type)
                            if curr_h > n_h:
                                vz1 = curr_h - 0.4
                                vz2 = n_h + 0.1
                                vy1: f64 = yf + 0.8
                                vy2: f64 = yf + 0.2
                                vxf: f64 = xf - 0.01
                                l0_w = get_vertex_light(vxf, vy1, px, py, pa, flash_on, level_type)
                                l1_w = get_vertex_light(vxf, vy2, px, py, pa, flash_on, level_type)
                                glColor3d(l0_w, l0_w, l0_w)
                                glTexCoord2d(0.0, vz1)
                                glVertex3d(vxf, vz1, vy1)
                                glColor3d(l1_w, l1_w, l1_w)
                                glTexCoord2d(1.0, vz1)
                                glVertex3d(vxf, vz1, vy2)
                                glColor3d(l1_w, l1_w, l1_w)
                                glTexCoord2d(1.0, vz2)
                                glVertex3d(vxf, vz2, vy2)
                                glColor3d(l0_w, l0_w, l0_w)
                                glTexCoord2d(0.0, vz2)
                                glVertex3d(vxf, vz2, vy1)

                            n_h = get_tile_h(x_d + 1, y_d, level_type)
                            if curr_h > n_h:
                                vz1 = curr_h - 0.4
                                vz2 = n_h + 0.1
                                vy1 = yf + 0.2
                                vy2 = yf + 0.8
                                vxf = xf + 1.01
                                l0_w = get_vertex_light(vxf, vy1, px, py, pa, flash_on, level_type)
                                l1_w = get_vertex_light(vxf, vy2, px, py, pa, flash_on, level_type)
                                glColor3d(l0_w, l0_w, l0_w)
                                glTexCoord2d(0.0, vz1)
                                glVertex3d(vxf, vz1, vy1)
                                glColor3d(l1_w, l1_w, l1_w)
                                glTexCoord2d(1.0, vz1)
                                glVertex3d(vxf, vz1, vy2)
                                glColor3d(l1_w, l1_w, l1_w)
                                glTexCoord2d(1.0, vz2)
                                glVertex3d(vxf, vz2, vy2)
                                glColor3d(l0_w, l0_w, l0_w)
                                glTexCoord2d(0.0, vz2)
                                glVertex3d(vxf, vz2, vy1)
            x_d = x_d + 1
        y_d = y_d + 1
    glEnd()

def main() -> int:
    srand((time(0 as *void)) as int)
    world_map = malloc(32768) as *int
    
    prop_x = malloc(3200) as *f64
    prop_y = malloc(3200) as *f64
    prop_type = malloc(1600) as *int
    
    init_level_1()

    console_hwnd: *void = GetConsoleWindow()
    ShowWindow(console_hwnd, 0)
    
    vis_map: *int = malloc(32768) as *int
    client_rect: *int = malloc(16) as *int
    
    wave_buf_idle_32: *u32 = malloc(16500) as *u32
    wave_buf_walk_32: *u32 = malloc(16500) as *u32
    wave_buf_run_32: *u32 = malloc(16500) as *u32
    wave_buf_mon_32: *u32 = malloc(16500) as *u32
    wave_buf_water_32: *u32 = malloc(16500) as *u32
    wave_buf_splash_32: *u32 = malloc(16500) as *u32
    
    wave_buf_idle_32[0] = 1179011410
    wave_buf_idle_32[1] = 16412
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
        wave_buf_water_32[i_h] = wave_buf_idle_32[i_h]
        wave_buf_splash_32[i_h] = wave_buf_idle_32[i_h]
        i_h = i_h + 1
        
    data_idle: *u8 = wave_buf_idle_32 as *u8
    data_walk: *u8 = wave_buf_walk_32 as *u8
    data_run: *u8 = wave_buf_run_32 as *u8
    data_mon: *u8 = wave_buf_mon_32 as *u8
    data_water: *u8 = wave_buf_water_32 as *u8
    data_splash: *u8 = wave_buf_splash_32 as *u8

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
        env_w_w: f64 = 0.0
        
        if 0.25 > beat_w:
            env_w: f64 = 1.0
            if 0.03 > beat_w:
                env_w = beat_w / 0.03
            else:
                env_w = 1.0 - ((beat_w - 0.03) / 0.22)
            thud_w = sin(beat_w * 45.0 * 6.2831853) * env_w * env_w * 1.5
            env_w_w = env_w
            
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
        
        water_noise: f64 = ((rand() % 255) as f64) - 128.0
        val_water: f64 = water_noise * env_w_w * 0.7 + 128.0
        if val_water > 255.0:
            val_water = 255.0
        if 0.0 > val_water:
            val_water = 0.0
        data_water[44 + wi] = val_water as u8
        
        t_s: f64 = (wi as f64) / 16384.0
        env_s: f64 = 1.0 - t_s
        env_s = env_s * env_s 
        splash_noise: f64 = ((rand() % 255) as f64) - 128.0
        val_s: f64 = splash_noise * env_s * 1.2 + 128.0
        if val_s > 255.0:
            val_s = 255.0
        if 0.0 > val_s:
            val_s = 0.0
        data_splash[44 + wi] = val_s as u8
        
        wi = wi + 1

    m_wi_j: int = 0
    while 16384 > m_wi_j:
        m_t_j: f64 = (m_wi_j as f64) / 8192.0
        
        step_idx: int = (m_t_j * 6.0) as int
        note: int = step_idx % 4
        base_f: f64 = 110.0
        if note == 0:
            base_f = 110.0
        elif note == 1:
            base_f = 116.54
        elif note == 2:
            base_f = 130.81
        else:
            base_f = 138.59
            
        base_f = base_f + sin(m_t_j * 3.14159265 * 12.0) * 8.0
        
        phase_j: f64 = m_t_j * base_f
        phase_int_j: int = phase_j as int
        fract_j: f64 = phase_j - (phase_int_j as f64)
        sq_val_j: f64 = -1.0
        if 0.5 > fract_j:
            sq_val_j = 1.0
            
        val_m: f64 = sq_val_j * 127.0 + 128.0
        if val_m > 255.0:
            val_m = 255.0
        if 0.0 > val_m:
            val_m = 0.0
        data_mon[44 + m_wi_j] = val_m as u8
        m_wi_j = m_wi_j + 1

    cls_name: *void = "CBLGameClass".data as *void
    win_name: *void = "Backrooms. The Found Footage.".data as *void
    
    h_inst: *void = GetModuleHandleA(0 as *void)
    
    wc: *WNDCLASSA = malloc(sizeof(WNDCLASSA)) as *WNDCLASSA
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
    free(wc as *int)

    hwnd: *void = CreateWindowExA(0, cls_name, win_name, 282001408, 100, 100, WINDOW_W, WINDOW_H, 0 as *void, 0 as *void, h_inst, 0 as *void)
    hdc: *void = GetDC(hwnd)
    
    pfd: *int = malloc(40) as *int
    pfd[0] = 65576 
    pfd[1] = 37    
    pfd[2] = 8192  
    pfd[3] = 0
    pfd[4] = 0
    pfd[5] = 0     
    pfd[6] = 530432 
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
    
    glEnable(2912) 
    glFogi(2917, 2048)
    glFogf(2914, 0.08 as float)
    
    fog_color: *float = malloc(16) as *float
    fog_color[0] = 0.01 as float
    fog_color[1] = 0.01 as float
    fog_color[2] = 0.01 as float
    fog_color[3] = 1.0 as float
    glFogfv(2918, fog_color)

    glClearColor(0.01 as float, 0.01 as float, 0.01 as float, 1.0 as float)
    glViewport(0, 0, WINDOW_W, WINDOW_H)

    tex_wall = create_texture(1)
    tex_wall_alt = create_texture(12)
    tex_chair = create_texture(13)
    tex_mirror = create_texture(14)
    
    tex_floor = create_texture(2)
    tex_ceil = create_texture(3)
    tex_ent = create_texture(4)
    tex_vig = create_texture(5)
    tex_vhs = create_texture(6)
    tex_dust = create_texture(7)
    
    tex_wall_2 = create_texture(8) 
    tex_floor_2 = create_texture(9)
    tex_ceil_2 = create_texture(11)

    PlaySoundA(wave_buf_idle_32 as *void, 0 as *void, 15)

    msg_raw: *int = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    msg_ptr: *MSG = msg_raw as *MSG
    msg_void: *void = msg_raw as *void

    game_state: int = 0         
    resume_state: int = 1
    state_timer: f64 = 0.0
    tutorial_timer: f64 = 0.0
    level_type: int = 0
    
    flashlight_on: int = 1
    flashlight_battery: f64 = 100.0
    player_stamina: f64 = 100.0
    
    f_key_debounce: int = 0
    flash_a: f64 = 0.0
    flash_pitch: f64 = 0.0
    
    m_key_debounce: int = 0
    esp_enabled: int = 0
    
    b_key_debounce: int = 0
    
    hole_x: int = 0
    text_ent: int = 0
    hole_y: int = 0
    hole_found: int = 0
    
    while hole_found == 0:
        hole_x = rand() % MAP_WIDTH
        hole_y = rand() % MAP_HEIGHT
        h_h: f64 = get_tile_h(hole_x, hole_y, 0)
        if 0.5 > h_h:
            dx_spawn: f64 = (hole_x as f64) - 2.5
            dy_spawn: f64 = (hole_y as f64) - 2.5
            if (dx_spawn * dx_spawn + dy_spawn * dy_spawn) > 400.0:
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

    pt: *int = malloc(8) as *int      
    
    key_buf: *char = malloc(2) as *char  
    key_buf[1] = 0 as char

    player_x: f64 = 2.5
    player_y: f64 = 2.5
    player_z: f64 = 0.0
    player_a: f64 = 0.0
    
    target_player_a: f64 = 0.0
    target_pitch_offset: f64 = 0.0
    current_pitch_offset: f64 = 0.0
    cam_roll_offset: f64 = 0.0
    
    fov: f64 = 1.3    
    cam_y: f64 = 0.55

    bob_timer: f64 = 0.0
    tremor_timer: f64 = 0.0
    
    is_parkouring: int = 0
    parkour_t: f64 = 0.0
    parkour_pitch_offset: f64 = 0.0
    parkour_roll_offset: f64 = 0.0
    
    is_deep_climbing: int = 0
    climb_anim_t: f64 = 0.0
    climb_pitch: f64 = 0.0
    climb_pitch_target: f64 = 0.0
    
    is_running: int = 1
    last_move_state: int = -1
    last_water_state: int = -1

    ent_dist_approx: f64 = 999.0
    is_looked_at: int = 0

    ent_x: f64 = 0.0
    ent_y: f64 = 0.0
    ent_active: int = 0
    ent_state: int = 0
    ent_timer: f64 = 0.0
    ent_audio_timer: f64 = 1.0
    
    last_time: int = clock() 
    thud_played: int = 0

    glitch_intensity: f64 = 0.0

    while is_running == 1:
        curr_time: int = clock()
        delta_ms: int = curr_time - last_time
        if 0 > delta_ms:
            delta_ms = 1
        if delta_ms == 0:
            delta_ms = 1
        last_time = curr_time
        delta_s: f64 = (delta_ms as f64) / 1000.0
        
        frame_start: int = clock()
        
        while PeekMessageA(msg_void, 0 as *void, 0, 0, 1) != 0:
            if msg_ptr.message == WM_QUIT:
                is_running = 0
            TranslateMessage(msg_void) 
            DispatchMessageA(msg_void)
            
        GetClientRect(hwnd, client_rect)
        if client_rect[2] > 0:
            current_w = client_rect[2]
            current_h = client_rect[3]
            glViewport(0, 0, current_w, current_h)

        if f11_debounce > 0:
            f11_debounce = f11_debounce - 1

        if (GetAsyncKeyState(122) & 32768) != 0:
            if f11_debounce == 0:
                if is_fullscreen == 0:
                    is_fullscreen = 1
                    sw: int = GetSystemMetrics(0)
                    sh: int = GetSystemMetrics(1)
                    SetWindowLongA(hwnd, -16, -1879048192) 
                    SetWindowPos(hwnd, 0 as *void, 0, 0, sw, sh, 100)
                else:
                    is_fullscreen = 0
                    SetWindowLongA(hwnd, -16, 282001408)
                    SetWindowPos(hwnd, 0 as *void, 100, 100, WINDOW_W, WINDOW_H, 100)
                f11_debounce = 30

        if menu_debounce > 0:
            menu_debounce = menu_debounce - 1

        is_playing: int = 0
        can_look: int = 0
        
        if game_state == 1:
            is_playing = 1
            can_look = 1
        if game_state == 4:
            is_playing = 1
        if game_state == 5:
            is_playing = 1
        if game_state == 6:
            is_playing = 1
            can_look = 1 
        if game_state == 7:
            is_playing = 1
        if game_state == 8:
            is_playing = 1
            can_look = 0

        if (GetAsyncKeyState(27) & 32768) != 0:
            if menu_debounce == 0:
                if game_state == 1:
                    resume_state = game_state
                    game_state = 0
                else:
                    if game_state == 0:
                        game_state = resume_state
                menu_debounce = 15

        if game_state == 0:
            if (GetAsyncKeyState(49) & 32768) != 0:
                if menu_debounce == 0: 
                    game_state = 4
                    state_timer = 0.0
                    tutorial_timer = 0.0
                    thud_played = 0
                    player_x = 2.5
                    player_y = 2.5
                    player_z = 0.0
                    player_a = 0.0
                    target_player_a = 0.0
                    level_type = 0
                    init_level_1()
                    
                    hole_found = 0
                    while hole_found == 0:
                        hole_x = rand() % MAP_WIDTH
                        hole_y = rand() % MAP_HEIGHT
                        restart_h_h: f64 = get_tile_h(hole_x, hole_y, 0)
                        if 0.5 > restart_h_h:
                            restart_dx: f64 = (hole_x as f64) - 2.5
                            restart_dy: f64 = (hole_y as f64) - 2.5
                            if (restart_dx * restart_dx + restart_dy * restart_dy) > 400.0:
                                hole_found = 1
                                
                    flash_a = 0.0
                    flash_pitch = -280.0
                    flashlight_on = 1
                    menu_debounce = 15
            if (GetAsyncKeyState(50) & 32768) != 0:
                if menu_debounce == 0: 
                    game_state = 2
                    menu_debounce = 15
            if (GetAsyncKeyState(51) & 32768) != 0:
                if menu_debounce == 0: 
                    is_running = 0

        if game_state == 2:
            if (GetAsyncKeyState(49) & 32768) != 0:
                if menu_debounce == 0: 
                    mouse_sens = mouse_sens + 0.001
                    if mouse_sens > 0.01:
                        mouse_sens = 0.001
                    menu_debounce = 15
            if (GetAsyncKeyState(50) & 32768) != 0:
                if menu_debounce == 0: 
                    game_state = 3
                    bind_target = 1
                    menu_debounce = 15
            if (GetAsyncKeyState(51) & 32768) != 0:
                if menu_debounce == 0: 
                    game_state = 3
                    bind_target = 2
                    menu_debounce = 15
            if (GetAsyncKeyState(52) & 32768) != 0:
                if menu_debounce == 0: 
                    game_state = 3
                    bind_target = 3
                    menu_debounce = 15
            if (GetAsyncKeyState(53) & 32768) != 0:
                if menu_debounce == 0: 
                    game_state = 3
                    bind_target = 4
                    menu_debounce = 15
            if (GetAsyncKeyState(54) & 32768) != 0:
                if menu_debounce == 0: 
                    game_state = 0
                    menu_debounce = 15

        if game_state == 3:
            k: int = 8
            while 255 > k:
                if (GetAsyncKeyState(k) & 32768) != 0:
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

            if (GetAsyncKeyState(78) & 32768) != 0: 
                if menu_debounce == 0:
                    if level_type == 0:
                        game_state = 5
                        state_timer = 0.0
                        ent_active = 0
                        menu_debounce = 15
        
        if is_playing == 0:
            if cursor_visible == 0:
                ShowCursor(1)
                cursor_visible = 1

        if f_key_debounce > 0:
            f_key_debounce = f_key_debounce - 1
        
        if b_key_debounce > 0:
            b_key_debounce = b_key_debounce - 1
        
        if m_key_debounce > 0:
            m_key_debounce = m_key_debounce - 1
            
        if is_playing == 1:
            if (GetAsyncKeyState(77) & 32768) != 0:
                if m_key_debounce == 0:
                    if esp_enabled == 1:
                        esp_enabled = 0
                    else:
                        esp_enabled = 1
                    m_key_debounce = 15

            if (GetAsyncKeyState(66) & 32768) != 0:
                if b_key_debounce == 0:
                    ent_x = player_x + sin(player_a) * 4.0
                    ent_y = player_y + cos(player_a) * 4.0
                    ent_active = 1
                    ent_state = 1
                    ent_timer = 0.0
                    b_key_debounce = 15
                    
            if game_state == 1:
                if (GetAsyncKeyState(70) & 32768) != 0:
                    if f_key_debounce == 0:
                        if flashlight_on == 1:
                            flashlight_on = 0
                        else:
                            if flashlight_battery > 0.0:
                                flashlight_on = 1
                        f_key_debounce = 15
                
                if (GetAsyncKeyState(75) & 32768) != 0:
                    game_state = 8
                    state_timer = 0.0
                    thud_played = 0
                    move_state = 1

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

        is_moving: int = 0
        if can_move == 1:
            if (GetAsyncKeyState(key_fwd) & 32768) != 0:
                is_moving = 1
            if (GetAsyncKeyState(key_bck) & 32768) != 0:
                is_moving = 1
            if (GetAsyncKeyState(key_lft) & 32768) != 0:
                is_moving = 1
            if (GetAsyncKeyState(key_rgt) & 32768) != 0:
                is_moving = 1

        move_state: int = 0
        if is_moving == 1:
            if (GetAsyncKeyState(16) & 32768) != 0:
                move_state = 2
            else:
                move_state = 1
        else:
            move_state = 0
            
        if move_state == 2:
            player_stamina = player_stamina - delta_s * 25.0
            if 0.0 > player_stamina:
                player_stamina = -10.0 
                move_state = 1
            else:
                if game_state == 1:
                    slip_chance: int = rand() % 10000
                    if slip_chance > 9995:
                        game_state = 8
                        state_timer = 0.0
                        thud_played = 0
                        move_state = 1
        else:
            player_stamina = player_stamina + delta_s * 15.0
            if player_stamina > 100.0:
                player_stamina = 100.0
                
        if 0.0 > player_stamina:
            move_state = 1 
            
        move_speed: f64 = 0.02
        bob_amp: f64 = 0.03
        
        if move_state == 2:
            move_speed = 0.045
            bob_amp = 0.07

        target_fov: f64 = 1.3
        if (GetAsyncKeyState(1) & 32768) != 0:
            target_fov = 0.6
        if (GetAsyncKeyState(2) & 32768) != 0:
            target_fov = 1.8
            
        if move_state == 2:
            target_fov = 1.45
            
        fov = fov + (target_fov - fov) * (delta_s * 6.0)

        player_map_x: int = player_x as int
        player_map_y: int = player_y as int
        target_z: f64 = get_tile_h(player_map_x, player_map_y, level_type)
        
        dz_climb: f64 = target_z - player_z
        is_climbing: int = 0
        
        if level_type == 2:
            if dz_climb > 0.8:
                if is_deep_climbing == 0:
                    is_deep_climbing = 1
                    climb_anim_t = 0.0

        if is_deep_climbing == 1:
            move_speed = 0.015
            climb_anim_t = climb_anim_t + delta_s
            
            if 0.4 > climb_anim_t:
                target_chest: f64 = target_z - 0.6
                player_z = player_z + (target_chest - player_z) * delta_s * 8.0
                climb_pitch_target = -35.0
            elif 1.1 > climb_anim_t:
                player_z = player_z + (target_z - player_z) * delta_s * 5.0
                climb_pitch_target = 45.0
            elif 1.5 > climb_anim_t:
                player_z = player_z + (target_z - player_z) * delta_s * 10.0
                climb_pitch_target = 0.0
            else:
                is_deep_climbing = 0
                climb_pitch_target = 0.0
                player_z = target_z
        else:
            if can_move == 1:
                if dz_climb > 0.2:
                    if move_state == 2:
                        if is_parkouring == 0:
                            is_parkouring = 1
                            parkour_t = 0.0

                if dz_climb > 0.05:
                    is_climbing = 1
                    if move_state == 2:
                        move_speed = move_speed * 0.75
                        player_z = player_z + dz_climb * delta_s * 6.0
                        climb_pitch_target = -15.0
                    else:
                        move_speed = move_speed * 0.3
                        player_z = player_z + dz_climb * delta_s * 3.5
                        climb_pitch_target = -15.0 - (dz_climb * 20.0)
                elif -0.05 > dz_climb:
                    player_z = player_z + dz_climb * delta_s * 8.0
                    climb_pitch_target = 10.0 - (dz_climb * 10.0)
                else:
                    player_z = player_z + dz_climb * delta_s * 8.0
                    climb_pitch_target = 0.0

        climb_pitch = climb_pitch + (climb_pitch_target - climb_pitch) * (delta_s * 10.0)

        is_in_water: int = 0
        if level_type == 2:
            if -0.2 > player_z:
                is_in_water = 1

        if is_in_water == 1:
            fog_color[0] = 0.0 as float
            fog_color[1] = 0.15 as float
            fog_color[2] = 0.3 as float
            glFogfv(2918, fog_color)
            glClearColor(0.0 as float, 0.15 as float, 0.3 as float, 1.0 as float)
            glFogf(2914, 0.25 as float)
        else:
            if level_type == 2:
                fog_color[0] = 0.7 as float
                fog_color[1] = 0.85 as float
                fog_color[2] = 0.9 as float
                glFogfv(2918, fog_color)
                glClearColor(0.7 as float, 0.85 as float, 0.9 as float, 1.0 as float)
                glFogf(2914, 0.05 as float)
            else:
                fog_color[0] = 0.01 as float
                fog_color[1] = 0.01 as float
                fog_color[2] = 0.01 as float
                glFogfv(2918, fog_color)
                glClearColor(0.01 as float, 0.01 as float, 0.01 as float, 1.0 as float)
                glFogf(2914, 0.08 as float)

        state_changed: int = 0
        if move_state != last_move_state:
            state_changed = 1
        if is_in_water != last_water_state:
            state_changed = 1
            if is_in_water == 1:
                PlaySoundA(wave_buf_splash_32 as *void, 0 as *void, 1)
            
        if can_move == 1:
            if state_changed == 1:
                last_move_state = move_state
                last_water_state = is_in_water
                bob_timer = 3.14159 
                if ent_state == 0:
                    if is_in_water == 1:
                        if move_state == 2:
                            PlaySoundA(wave_buf_water_32 as *void, 0 as *void, 15)
                        if move_state == 1:
                            PlaySoundA(wave_buf_water_32 as *void, 0 as *void, 15)
                        if move_state == 0:
                            PlaySoundA(0 as *void, 0 as *void, 0)
                    else:
                        if move_state == 2:
                            PlaySoundA(wave_buf_run_32 as *void, 0 as *void, 15)
                        if move_state == 1:
                            PlaySoundA(wave_buf_walk_32 as *void, 0 as *void, 15)
                        if move_state == 0:
                            PlaySoundA(wave_buf_idle_32 as *void, 0 as *void, 15)

        if is_moving == 1:
            if move_state == 2:
                bob_timer = bob_timer + delta_s * 17.0
            else:
                bob_timer = bob_timer + delta_s * 12.0

        if game_state == 4:
            state_timer = state_timer + delta_s
            if state_timer < 0.6:
                t_f_p: f64 = state_timer / 0.6
                cam_y = 1.45 - 1.3 * (t_f_p * t_f_p * t_f_p) 
                target_pitch_offset = -80.0
                cam_roll_offset = sin(t_f_p * 3.1415) * 15.0 
            elif state_timer < 1.5:
                if thud_played == 0:
                    PlaySoundA(wave_buf_walk_32 as *void, 0 as *void, 1)
                    thud_played = 1
                cam_y = 0.15
                target_pitch_offset = -80.0
                cam_roll_offset = 0.0
            elif state_timer < 2.0:
                t_f_p_2: f64 = (state_timer - 1.5) / 0.5
                b_t: f64 = t_f_p_2 * 2.0 - 1.0
                cam_y = 0.15 + 0.3 * (1.0 - b_t * b_t) 
                target_pitch_offset = -80.0 + 10.0 * t_f_p_2 
                cam_roll_offset = 0.0     
            elif state_timer < 3.5:
                cam_y = 0.15
                target_pitch_offset = -70.0
                cam_roll_offset = 0.0
            elif state_timer < 5.0:
                t_f_p_3: f64 = (state_timer - 3.5) / 1.5
                ease: f64 = t_f_p_3 * t_f_p_3 * (3.0 - 2.0 * t_f_p_3)
                cam_y = 0.15 + 0.4 * ease  
                target_pitch_offset = -70.0 * (1.0 - ease) 
            else:
                game_state = 1
                tutorial_timer = 0.0
                current_pitch_offset = 0.0
                target_pitch_offset = 0.0
                cam_roll_offset = 0.0
                thud_played = 0
                cam_y = 0.55

        if game_state == 5:
            state_timer = state_timer + delta_s
            t_f_p = state_timer / 2.5
            
            t_hx: f64 = (hole_x as f64) + 0.5
            t_hy: f64 = (hole_y as f64) + 0.5
            player_x = player_x + (t_hx - player_x) * delta_s * 6.0
            player_y = player_y + (t_hy - player_y) * delta_s * 6.0
            
            player_z = player_z - delta_s * 0.5
            if -0.3 > player_z:
                player_z = -0.3
            
            target_pitch_offset = 90.0
            current_pitch_offset = current_pitch_offset + (target_pitch_offset - current_pitch_offset) * delta_s * 5.0
            cam_roll_offset = cam_roll_offset + delta_s * 100.0 
            
            if state_timer > 2.5:
                game_state = 6 
                level_type = 2
                flashlight_on = 0
                init_level_2()
                player_x = 3.5
                player_y = 3.5
                player_z = -1.5 
                player_a = 0.0
                target_player_a = 0.0
                target_pitch_offset = -30.0 
                current_pitch_offset = -30.0
                cam_roll_offset = 0.0
                state_timer = 0.0
                PlaySoundA(wave_buf_splash_32 as *void, 0 as *void, 7)

        if game_state == 6:
            state_timer = state_timer + delta_s
            if state_timer < 3.0:
                t_f_p = state_timer / 3.0
                ease = t_f_p * t_f_p * (3.0 - 2.0 * t_f_p)
                player_z = -1.5 + 2.0 * ease 
                target_pitch_offset = -30.0 * (1.0 - ease) 
                current_pitch_offset = target_pitch_offset
            else:
                game_state = 1 
                player_z = 0.5
                current_pitch_offset = 0.0
                target_pitch_offset = 0.0

        if game_state == 7:
            state_timer = state_timer + delta_s
            if state_timer < 0.4:
                t_f_p = state_timer / 0.4
                cam_y = 0.55 - 0.4 * (t_f_p * t_f_p)
                current_pitch_offset = current_pitch_offset + (-85.0 - current_pitch_offset) * t_f_p
                cam_roll_offset = cam_roll_offset + (75.0 - cam_roll_offset) * t_f_p
                
                dir_x: f64 = player_x - ent_x
                dir_y: f64 = player_y - ent_y
                dist: f64 = sqrt(dir_x * dir_x + dir_y * dir_y) + 0.0001
                player_x = player_x + (dir_x / dist) * delta_s * 10.0 * (1.0 - t_f_p)
                player_y = player_y + (dir_y / dist) * delta_s * 10.0 * (1.0 - t_f_p)
            else:
                cam_y = 0.15
                current_pitch_offset = -85.0
                cam_roll_offset = 75.0
                
            if state_timer > 4.0:
                game_state = 0
                menu_debounce = 15
                ent_active = 0
                PlaySoundA(0 as *void, 0 as *void, 0)
                
        if game_state == 8:
            state_timer = state_timer + delta_s
            if state_timer < 0.3:
                t_f_p_4: f64 = state_timer / 0.3
                cam_y = 0.55 - 0.4 * t_f_p_4
                target_pitch_offset = -60.0 * t_f_p_4
                cam_roll_offset = 30.0 * t_f_p_4
            elif state_timer < 0.6:
                if thud_played == 0:
                    PlaySoundA(wave_buf_walk_32 as *void, 0 as *void, 1)
                    thud_played = 1
                t_f_p_5: f64 = (state_timer - 0.3) / 0.3
                b_t2: f64 = t_f_p_5 * 2.0 - 1.0
                cam_y = 0.15 + 0.15 * (1.0 - b_t2 * b_t2)
                target_pitch_offset = -60.0 - 15.0 * t_f_p_5
                cam_roll_offset = 30.0 + 45.0 * t_f_p_5
            elif state_timer < 2.0:
                cam_y = 0.15
                target_pitch_offset = -75.0
                cam_roll_offset = 75.0
            elif state_timer < 3.0:
                t_f_p_6: f64 = (state_timer - 2.0) / 1.0
                ease_2: f64 = t_f_p_6 * t_f_p_6 * (3.0 - 2.0 * t_f_p_6)
                cam_y = 0.15 + 0.4 * ease_2
                target_pitch_offset = -75.0 * (1.0 - ease_2)
                cam_roll_offset = 75.0 * (1.0 - ease_2)
            else:
                game_state = 1
                current_pitch_offset = 0.0
                target_pitch_offset = 0.0
                cam_roll_offset = 0.0
                cam_y = 0.55
                thud_played = 0

        if can_look == 1:
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

        if can_look == 1 or can_move == 1:
            player_a = player_a + (target_player_a - player_a) * (delta_s * 15.0)
            current_pitch_offset = current_pitch_offset + (target_pitch_offset - current_pitch_offset) * (delta_s * 15.0)

        if is_playing == 1:
            flash_a = flash_a + (player_a - flash_a) * (delta_s * 12.0)
            flash_pitch = flash_pitch + (current_pitch_offset - flash_pitch) * (delta_s * 12.0)

        if ent_active == 0:
            if game_state == 1:
                if level_type == 0: 
                    rx_int: int = rand() % (MAP_WIDTH - 2) + 1
                    ry_int: int = rand() % (MAP_HEIGHT - 2) + 1
                    if get_map(rx_int, ry_int) == 0:
                        dx_s: f64 = (rx_int as f64) - player_x
                        dy_s: f64 = (ry_int as f64) - player_y
                        if (dx_s * dx_s + dy_s * dy_s) > 400.0:
                            r_spawn: int = rand()
                            if 60 > (r_spawn % 100):
                                ent_x = (rx_int as f64) + 0.5
                                ent_y = (ry_int as f64) + 0.5
                                ent_active = 1
                                ent_state = 0
                                ent_timer = 0.0

        glitch_intensity = 0.0

        if ent_active == 1:
            if game_state == 1:
                if game_state != 7:
                    ent_timer = ent_timer + delta_s
                    if ent_timer > 20.0:
                        ent_active = 0
                        ent_state = 0
                        PlaySoundA(wave_buf_idle_32 as *void, 0 as *void, 15)
                        last_move_state = -1

        if ent_active == 1:
            dx_e: f64 = player_x - ent_x
            dy_e: f64 = player_y - ent_y
            dist_e_sq: f64 = dx_e * dx_e + dy_e * dy_e
            dist_e: f64 = sqrt(dist_e_sq) 
            
            if dist_e > 0.01:
                ent_dist_approx = dist_e
            else:
                ent_dist_approx = 0.01
                
            if 600.0 > dist_e_sq:
                glitch_intensity = 1.0 - (dist_e_sq / 600.0)
                if 0.0 > glitch_intensity:
                    glitch_intensity = 0.0
                
            if ent_state == 0:
                if game_state == 1 or game_state == 8:
                    if 225.0 > dist_e_sq:
                        has_los: int = 1
                        
                        ray_steps: int = (ent_dist_approx * 2.0) as int 
                        if ray_steps == 0:
                            ray_steps = 1
                        ray_dx: f64 = dx_e / (ray_steps as f64)
                        ray_dy: f64 = dy_e / (ray_steps as f64)
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
                            PlaySoundA(wave_buf_mon_32 as *void, 0 as *void, 15)
                        
            if ent_state == 1:
                if game_state == 1 or game_state == 8:
                    if dist_e_sq > 900.0:
                        ent_active = 0
                        ent_state = 0
                        PlaySoundA(wave_buf_idle_32 as *void, 0 as *void, 15)
                        last_move_state = -1
                    else:
                        ent_speed: f64 = 0.052
                        
                        norm_x: f64 = dx_e / ent_dist_approx
                        norm_y: f64 = dy_e / ent_dist_approx
                        
                        p_dx: f64 = sin(player_a)
                        p_dy: f64 = cos(player_a)
                        
                        dot_look: f64 = p_dx * (0.0 - norm_x) + p_dy * (0.0 - norm_y)
                        
                        is_looked_at = 0
                        if dot_look > 0.7:
                            if flashlight_on == 1:
                                is_looked_at = 1
                        
                        if is_looked_at == 1:
                            ent_speed = 0.01 
                        
                        nx_e: f64 = ent_x + norm_x * ent_speed
                        ny_e: f64 = ent_y + norm_y * ent_speed
                        
                        ent_xi: int = ent_x as int
                        ent_yi: int = ent_y as int
                        nxe_i: int = nx_e as int
                        nye_i: int = ny_e as int
                        
                        if can_walk(ent_xi, ent_yi, nxe_i, ent_yi, level_type) == 1:
                            ent_x = nx_e
                        if can_walk(ent_xi, ent_yi, ent_xi, nye_i, level_type) == 1:
                            ent_y = ny_e
                        
                        if 0.16 > dist_e_sq:
                            game_state = 7
                            state_timer = 0.0
                            PlaySoundA(wave_buf_mon_32 as *void, 0 as *void, 7)

        tremor_timer = tremor_timer + delta_s * 0.24 
        
        turn_diff: f64 = target_player_a - player_a
        cam_roll: f64 = sin(tremor_timer * 1.2) * 0.015
        
        if is_moving == 1:
            cam_roll = cam_roll + sin(bob_timer * 0.5) * 0.02
                
        if is_climbing == 1:
            cam_roll = cam_roll + sin((clock() as f64) * 0.015) * 0.03

        if is_in_water == 1:
            cam_roll = cam_roll + cos((clock() as f64) * 0.0015) * 0.03

        if is_parkouring == 1:
            parkour_t = parkour_t + delta_s * 1.8
            if parkour_t >= 1.0:
                is_parkouring = 0
                parkour_t = 0.0
                parkour_pitch_offset = 0.0
                parkour_roll_offset = 0.0
            else:
                p_ease: f64 = parkour_t * parkour_t * (3.0 - 2.0 * parkour_t)
                parkour_pitch_offset = p_ease * 360.0
                parkour_roll_offset = sin(parkour_t * 3.14159) * 15.0

        cam_pitch_f: f64 = sin(tremor_timer * 1.9) * 2.0
        bob_z: f64 = 0.0
        
        if is_moving == 1:
            cam_pitch_f = cam_pitch_f + sin(bob_timer * 1.0) * 3.0
            bob_z = (0.0 - cos(bob_timer)) * bob_amp 
            
        if is_in_water == 1:
            cam_pitch_f = cam_pitch_f + sin((clock() as f64) * 0.002) * 2.0
            
        if is_parkouring == 1:
            bob_z = bob_z - sin(parkour_t * 3.14159) * 0.4

        cam_pitch_f = cam_pitch_f + current_pitch_offset + climb_pitch
        
        tape_noise: f64 = ((rand() % 10) as f64 - 5.0) * (0.001 + glitch_intensity * 0.005)
        cam_pitch_f = cam_pitch_f + tape_noise * 5.0
        cam_roll = cam_roll + tape_noise * 2.0 
        
        glClear(17664) 

        glMatrixMode(5889)
        glLoadIdentity()
        
        aspect: f64 = (current_w as f64) / (current_h as f64)
        znear: f64 = 0.05 
        zfar: f64 = 55.0
        
        half_fov: f64 = fov * 0.5
        
        if is_in_water == 1:
            half_fov = half_fov * 0.9
            
        tan_half_fov: f64 = tan(half_fov)
        fh: f64 = znear * tan_half_fov
        fw: f64 = fh * aspect
        glFrustum(0.0 - fw, fw, 0.0 - fh, fh, znear, zfar)

        glMatrixMode(5888)
        glLoadIdentity()
        
        actual_flash: int = flashlight_on
        if glitch_intensity > 0.3:
            if (rand() % 100) > 60:
                actual_flash = 0

        if actual_flash == 1:
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

        cam_pitch_deg: f64 = cam_pitch_f * 0.3 + parkour_pitch_offset
        cam_roll_deg: f64 = cam_roll * 57.2957 + turn_diff * 40.0 + parkour_roll_offset + cam_roll_offset

        yaw_deg: f64 = player_a * 57.2957
        yaw_deg = yaw_deg + tape_noise * 2.0

        glRotated(cam_pitch_deg, 1.0, 0.0, 0.0)
        glRotated(cam_roll_deg, 0.0, 0.0, 1.0)
        glRotated(180.0 - yaw_deg, 0.0, 1.0, 0.0)

        breathing: f64 = sin(tremor_timer * 2.5) * 0.02
        if 30.0 > player_stamina:
            breathing = sin(tremor_timer * 4.0) * 0.06 
            
        if game_state != 4:
            if game_state != 7:
                if game_state != 8:
                    cam_y = 0.55 + bob_z + breathing

        glTranslated(0.0 - player_x, 0.0 - cam_y - player_z, 0.0 - player_y)

        calc_vis(player_x, player_y, vis_map)
        draw_world(player_x, player_y, flash_a, fov, vis_map, level_type, hole_x, hole_y, actual_flash, 0, 0, 0, 0.0)
        draw_props(player_x, player_y, flash_a, actual_flash, level_type, ent_active, ent_x, ent_y, yaw_deg, 0, 0, 0, 0.0)

        if esp_enabled == 1:
            glDisable(2929)
            glDisable(3553)
            glDisable(3042)
            glLineWidth(3.0 as float)
            glBegin(1)
            
            glColor3d(0.0, 1.0, 0.0)
            glVertex3d(player_x, player_z + cam_y - 0.2, player_y)
            glVertex3d((hole_x as f64) + 0.5, get_tile_h(hole_x, hole_y, 0), (hole_y as f64) + 0.5)
            
            if ent_active == 1:
                glColor3d(1.0, 0.0, 0.0)
                glVertex3d(player_x, player_z + cam_y - 0.2, player_y)
                glVertex3d(ent_x, 1.0, ent_y)
                
            glColor3d(0.0, 0.5, 1.0)
            yi_esp: int = 0
            while MAP_HEIGHT > yi_esp:
                xi_esp: int = 0
                while MAP_WIDTH > xi_esp:
                    if world_map[yi_esp * MAP_WIDTH + xi_esp] == 6:
                        glVertex3d(player_x, player_z + cam_y - 0.2, player_y)
                        glVertex3d((xi_esp as f64) + 0.5, 0.5, (yi_esp as f64) + 0.5)
                    xi_esp = xi_esp + 1
                yi_esp = yi_esp + 1
                
            glColor3d(1.0, 1.0, 0.0)
            ip_esp: int = 0
            while prop_count > ip_esp:
                glVertex3d(player_x, player_z + cam_y - 0.2, player_y)
                glVertex3d(prop_x[ip_esp], 0.5, prop_y[ip_esp])
                ip_esp = ip_esp + 1
                
            glEnd()
            glLineWidth(1.0 as float)
            glEnable(3553)
            glEnable(2929)

        if level_type == 0:
            mirror_x: int = -1
            mirror_y: int = -1
            min_dist: f64 = 9999.0
            
            ref_yd: int = 0
            while MAP_HEIGHT > ref_yd:
                ref_xd: int = 0
                while MAP_WIDTH > ref_xd:
                    if world_map[ref_yd * MAP_WIDTH + ref_xd] == 6:
                        if vis_map[ref_yd * MAP_WIDTH + ref_xd] == 1:
                            dx_r: f64 = (ref_xd as f64) + 0.5 - player_x
                            dy_r: f64 = (ref_yd as f64) + 0.5 - player_y
                            dsq_r: f64 = dx_r * dx_r + dy_r * dy_r
                            if min_dist > dsq_r:
                                min_dist = dsq_r
                                mirror_x = ref_xd
                                mirror_y = ref_yd
                    ref_xd = ref_xd + 1
                ref_yd = ref_yd + 1
                
            if mirror_x != -1:
                plane_x: f64 = 0.0
                plane_y: f64 = 0.0
                axis: int = 0
                
                dx_m: f64 = player_x - ((mirror_x as f64) + 0.5)
                dy_m: f64 = player_y - ((mirror_y as f64) + 0.5)
                
                if fabs(dx_m) > fabs(dy_m):
                    axis = 0
                    if dx_m > 0.0:
                        plane_x = (mirror_x as f64) + 1.0
                    else:
                        plane_x = (mirror_x as f64) + 0.0
                else:
                    axis = 1
                    if dy_m > 0.0:
                        plane_y = (mirror_y as f64) + 1.0
                    else:
                        plane_y = (mirror_y as f64) + 0.0
                        
                glEnable(2960)
                glStencilFunc(519, 1, 255) 
                glStencilOp(7680, 7680, 7681) 
                glColorMask(0, 0, 0, 0)
                glDepthMask(0)
                
                draw_mirrors(player_x, player_y, flash_a, actual_flash, level_type, vis_map, mirror_x, mirror_y)
                
                glColorMask(1, 1, 1, 1)
                glDepthMask(1)
                glClear(256) 
                
                glStencilFunc(514, 1, 255) 
                glStencilOp(7680, 7680, 7680) 
                
                glPushMatrix()
                if axis == 0:
                    glTranslated(plane_x, 0.0, 0.0)
                    glScaled(-1.0, 1.0, 1.0)
                    glTranslated(0.0 - plane_x, 0.0, 0.0)
                else:
                    glTranslated(0.0, 0.0, plane_y)
                    glScaled(1.0, 1.0, -1.0)
                    glTranslated(0.0, 0.0, 0.0 - plane_y)
                    
                glFrontFace(2304) 
                
                c_dir: int = 1
                p_coord: f64 = plane_x
                m_px: f64 = player_x
                m_py: f64 = player_y
                m_pa: f64 = player_a
                
                if axis == 0:
                    if dx_m > 0.0:
                        c_dir = 1
                    else:
                        c_dir = 0
                    m_px = 2.0 * plane_x - player_x
                    m_pa = 0.0 - player_a
                else:
                    p_coord = plane_y
                    if dy_m > 0.0:
                        c_dir = 1
                    else:
                        c_dir = 0
                    m_py = 2.0 * plane_y - player_y
                    m_pa = 3.14159265 - player_a

                draw_world(m_px, m_py, m_pa, fov, vis_map, level_type, hole_x, hole_y, actual_flash, 1, axis, c_dir, p_coord)
                draw_props(m_px, m_py, m_pa, actual_flash, level_type, ent_active, ent_x, ent_y, yaw_deg, 1, axis, c_dir, p_coord)
                
                draw_text_3d(player_x - 0.15, player_z + cam_y - 0.1, player_y, "Me", 0.9, 0.9, 0.9, 1.0)
                
                glFrontFace(2305) 
                glPopMatrix()
                
                glDepthFunc(515)
                glEnable(3042)
                glBlendFunc(770, 771)
                glBindTexture(3553, tex_mirror)
                draw_mirrors(player_x, player_y, flash_a, actual_flash, level_type, vis_map, mirror_x, mirror_y)
                
                glDisable(2960)

        cw: f64 = current_w as f64
        ch: f64 = current_h as f64

        glMatrixMode(5889)
        glLoadIdentity()
        glOrtho(0.0, cw, ch, 0.0, -1.0, 1.0)
        glMatrixMode(5888)
        glLoadIdentity()
        glDisable(2929) 

        if game_state == 7:
            glDisable(3553)
            glEnable(3042)
            glBlendFunc(770, 771)
            
            glLineWidth(4.0 as float)
            glColor4d(0.0, 0.0, 0.0, 0.8)
            glBegin(1)
            glVertex3d(cw * 0.5, ch * 0.5, 0.0)
            glVertex3d(cw * 0.3, ch * 0.2, 0.0)
            glVertex3d(cw * 0.3, ch * 0.2, 0.0)
            glVertex3d(cw * 0.1, ch * 0.1, 0.0)
            
            glVertex3d(cw * 0.5, ch * 0.5, 0.0)
            glVertex3d(cw * 0.7, ch * 0.8, 0.0)
            glVertex3d(cw * 0.7, ch * 0.8, 0.0)
            glVertex3d(cw * 0.9, ch * 0.9, 0.0)
            
            glVertex3d(cw * 0.5, ch * 0.5, 0.0)
            glVertex3d(cw * 0.8, ch * 0.3, 0.0)
            glEnd()
            glLineWidth(1.0 as float)
            
            fade_a: f64 = 0.0
            if state_timer > 1.0:
                fade_a = (state_timer - 1.0) / 3.0
                if fade_a > 1.0:
                    fade_a = 1.0
            glColor4d(0.8, 0.0, 0.0, fade_a * 0.8) 
            glBegin(7)
            glVertex3d(0.0, 0.0, 0.0)
            glVertex3d(cw, 0.0, 0.0)
            glVertex3d(cw, ch, 0.0)
            glVertex3d(0.0, ch, 0.0)
            glEnd()
            glEnable(3553)
        
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
            shift_x = shift_x + glitch_intensity * (((rand() % 100) as f64) / 150.0)
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
            
            tint_b: f64 = 0.0
            if is_in_water == 1:
                tint_b = 0.25 
                
            glColor4d(0.1, 0.05, tint_b, 0.1)
            glBegin(7)
            glVertex3d(0.0, 0.0, 0.0)
            glVertex3d(cw, 0.0, 0.0)
            glVertex3d(cw, ch, 0.0)
            glVertex3d(0.0, ch, 0.0)
            glEnd()
            glEnable(3553)
            glDisable(3042)
            
            blink_rec: int = (clock() / 1000) % 2
            if blink_rec == 1:
                draw_text(40.0, 40.0, "REC", 1.0, 0.1, 0.1, 0.9)
            draw_text(cw - 280.0, ch - 80.0, "JUL. 04 1990", 1.0, 1.0, 1.0, 0.8)
            draw_text(cw - 280.0, ch - 50.0, "AM 08:45", 1.0, 1.0, 1.0, 0.8)

            if game_state == 5:
                glEnable(3042)
                glDisable(3553)
                glBlendFunc(770, 771)
                
                fade_fall: f64 = state_timer / 1.5
                fade_fall = fade_fall * fade_fall * 1.5
                if fade_fall > 1.0:
                    fade_fall = 1.0
                    
                glColor4d(0.0, 0.0, 0.0, fade_fall)
                glBegin(7)
                glVertex3d(0.0, 0.0, 0.0)
                glVertex3d(cw, 0.0, 0.0)
                glVertex3d(cw, ch, 0.0)
                glVertex3d(0.0, ch, 0.0)
                glEnd()
                glEnable(3553)
                glDisable(3042)
                
            if game_state == 6:
                glEnable(3042)
                glDisable(3553)
                glBlendFunc(770, 771)
                
                fade_in: f64 = 1.0 - (state_timer / 1.0)
                if 0.0 > fade_in:
                    fade_in = 0.0
                
                glColor4d(0.0, 0.0, 0.0, fade_in)
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
                
                draw_text(50.0, ch - 200.0, "STAMINA", 1.0, 1.0, 1.0, tut_alpha)
                draw_text(50.0, ch - 170.0, "W A S D - MOVE", 1.0, 1.0, 1.0, tut_alpha)
                draw_text(50.0, ch - 140.0, "SHIFT - RUN", 1.0, 1.0, 1.0, tut_alpha)
                draw_text(50.0, ch - 110.0, "F - FLASHLIGHT", 1.0, 1.0, 1.0, tut_alpha)
                draw_text(50.0, ch - 80.0, "FIND THE BLACK HOLE TO ESCAPE", 1.0, 1.0, 1.0, tut_alpha)
                
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
                key_buf[0] = key_fwd as char
                draw_char(cen_x + 120.0, cen_y - 60.0, key_buf as *void, 1.0, 1.0, 1.0, 1.0)
                
                draw_text(cen_x - 80.0, cen_y - 10.0, "3. BIND BACKWARD: ", 1.0, 1.0, 1.0, 1.0)
                key_buf[0] = key_bck as char
                draw_char(cen_x + 120.0, cen_y - 10.0, key_buf as *void, 1.0, 1.0, 1.0, 1.0)
                
                draw_text(cen_x - 80.0, cen_y + 40.0, "4. BIND LEFT: ", 1.0, 1.0, 1.0, 1.0)
                key_buf[0] = key_lft as char
                draw_char(cen_x + 120.0, cen_y + 40.0, key_buf as *void, 1.0, 1.0, 1.0, 1.0)
                
                draw_text(cen_x - 80.0, cen_y + 90.0, "5. BIND RIGHT: ", 1.0, 1.0, 1.0, 1.0)
                key_buf[0] = key_rgt as char
                draw_char(cen_x + 120.0, cen_y + 90.0, key_buf as *void, 1.0, 1.0, 1.0, 1.0)
                
                draw_text(cen_x - 80.0, cen_y + 140.0, "6. BACK", 1.0, 1.0, 1.0, 1.0)

            if game_state == 3:
                draw_text(cen_x - 80.0, cen_y, "PRESS ANY KEY...", 1.0, 1.0, 1.0, 1.0)

        glDisable(3042)
        glEnable(2929)
        
        SwapBuffers(hdc)

        if can_move == 1:
            next_x: f64 = player_x
            next_y: f64 = player_y

            if (GetAsyncKeyState(key_fwd) & 32768) != 0:
                next_x = next_x + sin(player_a) * move_speed
                next_y = next_y + cos(player_a) * move_speed
            if (GetAsyncKeyState(key_bck) & 32768) != 0:
                next_x = next_x - sin(player_a) * move_speed
                next_y = next_y - cos(player_a) * move_speed
            if (GetAsyncKeyState(key_lft) & 32768) != 0:
                next_x = next_x + cos(player_a) * move_speed
                next_y = next_y - sin(player_a) * move_speed
            if (GetAsyncKeyState(key_rgt) & 32768) != 0:
                next_x = next_x - cos(player_a) * move_speed
                next_y = next_y + sin(player_a) * move_speed

            pad: f64 = 0.25
            nx_p: int = (next_x + pad) as int
            nx_m: int = (next_x - pad) as int
            py_p: int = (player_y + pad) as int
            py_m: int = (player_y - pad) as int

            cx_i: int = player_x as int
            cy_i: int = player_y as int

            if can_walk(cx_i, cy_i, nx_p, py_p, level_type) == 1:
                if can_walk(cx_i, cy_i, nx_p, py_m, level_type) == 1:
                    if can_walk(cx_i, cy_i, nx_m, py_p, level_type) == 1:
                        if can_walk(cx_i, cy_i, nx_m, py_m, level_type) == 1:
                            player_x = next_x
                
            ny_p: int = (next_y + pad) as int
            ny_m: int = (next_y - pad) as int
            px_p: int = (player_x + pad) as int
            px_m: int = (player_x - pad) as int

            if can_walk(cx_i, cy_i, px_p, ny_p, level_type) == 1:
                if can_walk(cx_i, cy_i, px_p, ny_m, level_type) == 1:
                    if can_walk(cx_i, cy_i, px_m, ny_p, level_type) == 1:
                        if can_walk(cx_i, cy_i, px_m, ny_m, level_type) == 1:
                            player_y = next_y
            
            if game_state == 1:
                if level_type == 0:
                    px_int: int = player_x as int
                    py_int: int = player_y as int
                    if px_int == hole_x:
                        if py_int == hole_y:
                            game_state = 5
                            state_timer = 0.0
            
        frame_time: int = clock() - frame_start
        if 16 > frame_time:
            Sleep(16 - frame_time)
        else:
            Sleep(1)

    PlaySoundA(0 as *void, 0 as *void, 0)
    
    free(fog_color as *int)
    wglMakeCurrent(0 as *void, 0 as *void)
    wglDeleteContext(hrc)
    DeleteObject(hfont)
    
    free(prop_x as *int)
    free(prop_y as *int)
    free(prop_type as *int)
    
    free(wave_buf_idle_32 as *int)
    free(wave_buf_walk_32 as *int)
    free(wave_buf_run_32 as *int)
    free(wave_buf_mon_32 as *int)
    free(wave_buf_water_32 as *int)
    free(wave_buf_splash_32 as *int)
    
    free(pt)
    free(key_buf as *int)
    free(vis_map)
    free(client_rect)
    free(world_map as *int)
    
    ShowCursor(1) 
    ReleaseDC(hwnd, hdc)
    ExitProcess(0)
    endofcode
