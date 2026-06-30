extern def GetModuleHandleA(lpModuleName: *char) -> *void
extern def RegisterClassA(lpWndClass: *void) -> u16
extern def CreateWindowExA(dwExStyle: u32, lpClassName: *char, lpWindowName: *char, dwStyle: u32, x: int, y: int, nWidth: int, nHeight: int, hWndParent: *void, hMenu: *void, hInstance: *void, lpParam: *void) -> *void
extern def PeekMessageA(lpMsg: *void, hWnd: *void, wMsgFilterMin: u32, wMsgFilterMax: u32, wRemoveMsg: u32) -> int
extern def TranslateMessage(lpMsg: *void) -> int
extern def DispatchMessageA(lpMsg: *void) -> u64
extern def DefWindowProcA(hWnd: *void, Msg: u32, wParam: u64, lParam: u64) -> u64
extern def PostQuitMessage(nExitCode: int) -> void
extern def Sleep(dwMilliseconds: u32) -> void
extern def GetDC(hWnd: *void) -> *void
extern def SetWindowTextA(hwnd: *void, lpString: *char) -> int

extern def ChoosePixelFormat(hdc: *void, ppfd: *void) -> int
extern def SetPixelFormat(hdc: *void, format: int, ppfd: *void) -> int
extern def SwapBuffers(hdc: *void) -> int
extern def wglCreateContext(hdc: *void) -> *void
extern def wglMakeCurrent(hdc: *void, hglrc: *void) -> int
extern def glClearColor(red: float, green: float, blue: float, alpha: float) -> void
extern def glClear(mask: u32) -> void
extern def glLoadIdentity() -> void
extern def glOrtho(left: f64, right: f64, bottom: f64, top: f64, zNear: f64, zFar: f64) -> void
extern def glBegin(mode: u32) -> void
extern def glEnd() -> void
extern def glVertex2f(x: float, y: float) -> void
extern def glColor3f(red: float, green: float, blue: float) -> void
extern def glViewport(x: int, y: int, w: int, h: int) -> void
extern def glPointSize(size: float) -> void

struct POINT:
    x: int
    y: int

struct MSG:
    hwnd: *void
    message: u32
    wParam: u64
    lParam: u64
    time: u32
    pt: POINT
    lPrivate: u32

struct WNDCLASSA:
    style: u32
    lpfnWndProc: *void
    cbClsExtra: int
    cbWndExtra: int
    hInstance: *void
    hIcon: *void
    hCursor: *void
    hbrBackground: *void
    lpszMenuName: *char
    lpszClassName: *char

struct PIXELFORMATDESCRIPTOR:
    nSize: u16
    nVersion: u16
    dwFlags: u32
    iPixelType: u8
    cColorBits: u8
    cRedBits: u8
    cRedShift: u8
    cGreenBits: u8
    cGreenShift: u8
    cBlueBits: u8
    cBlueShift: u8
    cAlphaBits: u8
    cAlphaShift: u8
    cAccumBits: u8
    cAccumRedBits: u8
    cAccumGreenBits: u8
    cAccumBlueBits: u8
    cAccumAlphaBits: u8
    cDepthBits: u8
    cStencilBits: u8
    cAuxBuffers: u8
    iLayerType: u8
    bReserved: u8
    dwLayerMask: u32
    dwVisibleMask: u32
    dwDamageMask: u32

struct Vec2:
    x: float
    y: float

struct Particle:
    pos: Vec2
    old_pos: Vec2
    vel: Vec2
    force: Vec2
    mass: float
    inv_mass: float
    radius: float
    restitution: float
    r: float
    g: float
    b: float

struct Spring:
    p1: int
    p2: int
    rest_len: float

let g_cam_x = 10.0
let g_cam_y = 20.0
let g_cam_zoom = 25.0
let g_width = 800.0
let g_height = 600.0

let g_mouse_wx = 0.0
let g_mouse_wy = 0.0
let g_mouse_down = 0
let g_grabbed = -1

let g_mode = 0
let g_reset_req = 1

let g_num_parts = 0
let g_num_springs = 0

def init_scene(particles: *Particle, springs: *Spring):
    g_num_parts = 0
    g_num_springs = 0
    
    if g_mode == 0 or g_mode == 1:
        g_num_parts = 40
        for i in 0..40:
            let p = &particles[i]
            p.radius = 1.0 + (rand() % 20) as float / 10.0
            p.mass = p.radius * p.radius * 3.14
            if g_mode == 1:
                p.mass = p.mass * 20.0
            p.inv_mass = 1.0 / p.mass
            p.pos = { (rand() % 40) as float - 10.0, 10.0 + (rand() % 40) as float } as Vec2
            p.vel = { 0.0, 0.0 } as Vec2
            p.r = (rand() % 100) as float / 100.0
            p.g = (rand() % 100) as float / 100.0
            p.b = (rand() % 100) as float / 100.0
            p.restitution = 0.5
            
    if g_mode == 2: # Ткань
        let cols = 18
        let rows = 18
        let spacing = 1.2
        g_num_parts = cols * rows
        for y in 0..rows:
            for x in 0..cols:
                let idx = y * cols + x
                let p = &particles[idx]
                p.pos = { (x as float) * spacing - 10.0, 40.0 - (y as float) * spacing } as Vec2
                p.old_pos = p.pos
                p.vel = { 0.0, 0.0 } as Vec2
                p.radius = 0.4
                p.r = 0.9
                p.g = 0.2
                p.b = 0.3
                p.mass = 1.0
                if y == 0:
                    p.inv_mass = 0.0
                else:
                    p.inv_mass = 1.0
                    
        for y in 0..rows:
            for x in 0..cols:
                let idx = y * cols + x
                if x < cols - 1:
                    let s = &springs[g_num_springs]
                    s.p1 = idx
                    s.p2 = idx + 1
                    s.rest_len = spacing
                    g_num_springs = g_num_springs + 1
                if y < rows - 1:
                    let s = &springs[g_num_springs]
                    s.p1 = idx
                    s.p2 = idx + cols
                    s.rest_len = spacing
                    g_num_springs = g_num_springs + 1

    if g_mode == 3 or g_mode == 4 or g_mode == 5:
        g_num_parts = 600
        for i in 0..600:
            let p = &particles[i]
            p.radius = 0.5
            p.mass = 1.0
            p.inv_mass = 1.0
            p.pos = { (i % 25) as float * 1.2 - 5.0, 10.0 + (i / 25) as float * 1.2 } as Vec2
            p.old_pos = p.pos
            p.vel = { 0.0, 0.0 } as Vec2
            
            if g_mode == 3: # Песок
                p.r = 0.9
                p.g = 0.8
                p.b = 0.4
            if g_mode == 4: # Вода
                p.r = 0.2
                p.g = 0.5
                p.b = 0.9
            if g_mode == 5: # Слизь
                p.r = 0.4
                p.g = 0.9
                p.b = 0.2

def resolve_rigid(a: *Particle, b: *Particle):
    if a.inv_mass == 0.0 and b.inv_mass == 0.0:
        return

    let nx = b.pos.x - a.pos.x
    let ny = b.pos.y - a.pos.y
    let dist = sqrt(nx*nx + ny*ny)
    let penetration = a.radius + b.radius - dist

    if penetration <= 0.0:
        return 
    if dist == 0.0:
        nx = 0.0
        ny = 1.0
        dist = 1.0
    else:
        nx = nx / dist
        ny = ny / dist

    let rvx = b.vel.x - a.vel.x
    let rvy = b.vel.y - a.vel.y
    let vel_along_normal = rvx * nx + rvy * ny

    if vel_along_normal > 0.0:
        return

    let e = a.restitution
    if b.restitution < e:
        e = b.restitution

    let j = -(1.0 + e) * vel_along_normal
    j = j / (a.inv_mass + b.inv_mass)

    let ix = nx * j
    let iy = ny * j
    
    a.vel.x = a.vel.x - ix * a.inv_mass
    a.vel.y = a.vel.y - iy * a.inv_mass
    b.vel.x = b.vel.x + ix * b.inv_mass
    b.vel.y = b.vel.y + iy * b.inv_mass

    let percent = 0.6
    let slop = 0.01
    let corr = penetration - slop
    if corr < 0.0:
        corr = 0.0
    corr = (corr / (a.inv_mass + b.inv_mass)) * percent
    
    a.pos.x = a.pos.x - nx * corr * a.inv_mass
    a.pos.y = a.pos.y - ny * corr * a.inv_mass
    b.pos.x = b.pos.x + nx * corr * b.inv_mass
    b.pos.y = b.pos.y + ny * corr * b.inv_mass

def resolve_fluid(a: *Particle, b: *Particle):
    let dx = b.pos.x - a.pos.x
    let dy = b.pos.y - a.pos.y
    let d2 = dx*dx + dy*dy
    let rad = a.radius + b.radius
    
    if d2 < rad*rad and d2 > 0.0001:
        let d = sqrt(d2)
        let overlap = rad - d
        let nx = dx / d
        let ny = dy / d
        
        if g_mode == 3: # Песок
            let push = overlap * 0.5
            a.pos.x = a.pos.x - nx * push
            a.pos.y = a.pos.y - ny * push
            b.pos.x = b.pos.x + nx * push
            b.pos.y = b.pos.y + ny * push
            
            let tx = -ny
            let ty = nx
            let v1x = a.pos.x - a.old_pos.x
            let v1y = a.pos.y - a.old_pos.y
            let v2x = b.pos.x - b.old_pos.x
            let v2y = b.pos.y - b.old_pos.y
            let tv = (v2x - v1x) * tx + (v2y - v1y) * ty
            a.old_pos.x = a.old_pos.x - tx * tv * 0.8
            a.old_pos.y = a.old_pos.y - ty * tv * 0.8
            b.old_pos.x = b.old_pos.x + tx * tv * 0.8
            b.old_pos.y = b.old_pos.y + ty * tv * 0.8

        if g_mode == 4: # Вода
            let force = overlap * 0.3
            if overlap < 0.3:
                force = force - 0.04
            a.pos.x = a.pos.x - nx * force
            a.pos.y = a.pos.y - ny * force
            b.pos.x = b.pos.x + nx * force
            b.pos.y = b.pos.y + ny * force

        if g_mode == 5: # Неньютоновская жидкость
            let v1x = a.pos.x - a.old_pos.x
            let v1y = a.pos.y - a.old_pos.y
            let v2x = b.pos.x - b.old_pos.x
            let v2y = b.pos.y - b.old_pos.y
            let rvx = v2x - v1x
            let rvy = v2y - v1y
            let rel_v = sqrt(rvx*rvx + rvy*rvy)
            
            let force = overlap * 0.2 + rel_v * 0.6
            a.pos.x = a.pos.x - nx * force
            a.pos.y = a.pos.y - ny * force
            b.pos.x = b.pos.x + nx * force
            b.pos.y = b.pos.y + ny * force

def update_physics(particles: *Particle, springs: *Spring, dt: float):
    if g_mouse_down == 1:
        if g_grabbed == -1:
            let min_d = 10000.0
            for i in 0..g_num_parts:
                let p = &particles[i]
                let dx = p.pos.x - g_mouse_wx
                let dy = p.pos.y - g_mouse_wy
                let d = sqrt(dx*dx + dy*dy)
                if d < p.radius * 4.0 and d < min_d:
                    min_d = d
                    g_grabbed = i
        
        if g_grabbed != -1:
            let p = &particles[g_grabbed]
            if g_mode == 0 or g_mode == 1:
                p.vel.x = (g_mouse_wx - p.pos.x) * 15.0
                p.vel.y = (g_mouse_wy - p.pos.y) * 15.0
            else:
                p.pos.x = g_mouse_wx
                p.pos.y = g_mouse_wy

    if g_mode == 0 or g_mode == 1:
        for i in 0..g_num_parts:
            let p = &particles[i]
            if p.inv_mass > 0.0:
                p.vel.y = p.vel.y - 9.81 * dt
                p.pos.x = p.pos.x + p.vel.x * dt
                p.pos.y = p.pos.y + p.vel.y * dt
    else:
        for i in 0..g_num_parts:
            let p = &particles[i]
            if p.inv_mass > 0.0 and i != g_grabbed:
                let vx = (p.pos.x - p.old_pos.x) * 0.99
                let vy = (p.pos.y - p.old_pos.y) * 0.99
                p.old_pos = p.pos
                p.pos.x = p.pos.x + vx
                p.pos.y = p.pos.y + vy - 9.81 * dt * dt

    let substeps = 4
    if g_mode == 0 or g_mode == 1:
        substeps = 1

    for step in 0..substeps:
        if g_mode == 0 or g_mode == 1:
            for i in 0..g_num_parts:
                let n = i + 1
                for j in n..g_num_parts:
                    resolve_rigid(&particles[i], &particles[j])
                    
        if g_mode == 2:
            for i in 0..g_num_springs:
                let s = &springs[i]
                let p1 = &particles[s.p1]
                let p2 = &particles[s.p2]
                let dx = p2.pos.x - p1.pos.x
                let dy = p2.pos.y - p1.pos.y
                let d = sqrt(dx*dx + dy*dy)
                if d > 0.001:
                    let diff = (d - s.rest_len) / d
                    let ox = dx * diff * 0.5
                    let oy = dy * diff * 0.5
                    if p1.inv_mass > 0.0:
                        p1.pos.x = p1.pos.x + ox
                        p1.pos.y = p1.pos.y + oy
                    if p2.inv_mass > 0.0:
                        p2.pos.x = p2.pos.x - ox
                        p2.pos.y = p2.pos.y - oy
                        
        if g_mode == 3 or g_mode == 4 or g_mode == 5:
            for i in 0..g_num_parts:
                let n = i + 1
                for j in n..g_num_parts:
                    resolve_fluid(&particles[i], &particles[j])

        for i in 0..g_num_parts:
            let p = &particles[i]
            if p.pos.y - p.radius < 0.0:
                if g_mode == 0 or g_mode == 1:
                    p.pos.y = p.radius
                    p.vel.y = -p.vel.y * p.restitution
                    p.vel.x = p.vel.x * 0.95
                else:
                    p.pos.y = p.radius
                    let vx = (p.pos.x - p.old_pos.x) * 0.5
                    p.old_pos.x = p.pos.x - vx
                    
            if p.pos.x - p.radius < -25.0:
                p.pos.x = -25.0 + p.radius
                if g_mode == 0 or g_mode == 1:
                    p.vel.x = -p.vel.x * p.restitution
            if p.pos.x + p.radius > 45.0:
                p.pos.x = 45.0 - p.radius
                if g_mode == 0 or g_mode == 1:
                    p.vel.x = -p.vel.x * p.restitution

def render(particles: *Particle, springs: *Spring):
    glClearColor(0.1, 0.1, 0.15, 1.0)
    glClear(16384) 
    
    glLoadIdentity()
    let aspect = g_width / g_height
    let w = g_cam_zoom * aspect
    glOrtho((g_cam_x - w) as f64, (g_cam_x + w) as f64, (g_cam_y - g_cam_zoom) as f64, (g_cam_y + g_cam_zoom) as f64, -1.0 as f64, 1.0 as f64)
    
    glColor3f(0.2, 0.25, 0.2)
    glBegin(7) 
    glVertex2f(-100.0, 0.0)
    glVertex2f(100.0, 0.0)
    glVertex2f(100.0, -10.0)
    glVertex2f(-100.0, -10.0)
    
    glVertex2f(-26.0, 100.0)
    glVertex2f(-25.0, 100.0)
    glVertex2f(-25.0, 0.0)
    glVertex2f(-26.0, 0.0)
    
    glVertex2f(45.0, 100.0)
    glVertex2f(46.0, 100.0)
    glVertex2f(46.0, 0.0)
    glVertex2f(45.0, 0.0)
    glEnd()
    
    if g_mode == 2:
        glColor3f(0.6, 0.6, 0.6)
        glBegin(1)
        for i in 0..g_num_springs:
            let s = &springs[i]
            glVertex2f(particles[s.p1].pos.x, particles[s.p1].pos.y)
            glVertex2f(particles[s.p2].pos.x, particles[s.p2].pos.y)
        glEnd()
        
    for i in 0..g_num_parts:
        let p = &particles[i]
        glColor3f(p.r, p.g, p.b)
        
        if g_mode == 0 or g_mode == 1:
            glBegin(6) 
            glVertex2f(p.pos.x, p.pos.y)
            for j in 0..13:
                let theta = (j as float) * 3.14159 * 2.0 / 12.0
                glVertex2f(p.pos.x + cos(theta) * p.radius, p.pos.y + sin(theta) * p.radius)
            glEnd()
        else:
            let psize = p.radius * g_height / g_cam_zoom * 0.8
            glPointSize(psize)
            glBegin(0) 
            glVertex2f(p.pos.x, p.pos.y)
            glEnd()

def update_title(hwnd: *void):
    let title = "FluxPhysics | [1]Rigid [2]Heavy [3]Cloth [4]Sand [5]Water [6]Slime | WASD=Cam | Mouse=Grab".data
    SetWindowTextA(hwnd, title)

def WindowProc(hwnd: *void, msg: u32, wParam: u64, lParam: u64) -> u64:
    if msg == 2:
        PostQuitMessage(0)
        endofcode
    if msg == 5:
        g_width = (lParam & 0xFFFF) as float
        g_height = ((lParam / 65536) & 0xFFFF) as float
        glViewport(0, 0, g_width as int, g_height as int)
        endofcode
    if msg == 513:
        g_mouse_down = 1
        endofcode
    if msg == 514:
        g_mouse_down = 0
        g_grabbed = -1
        endofcode
    if msg == 512:
        let sx = (lParam & 0xFFFF) as float
        let sy = ((lParam / 65536) & 0xFFFF) as float
        let aspect = g_width / g_height
        let w = g_cam_zoom * aspect
        g_mouse_wx = g_cam_x + (sx / g_width * 2.0 - 1.0) * w
        g_mouse_wy = g_cam_y - (sy / g_height * 2.0 - 1.0) * g_cam_zoom
        endofcode
    if msg == 522:
        let delta = ((wParam / 65536) & 0xFFFF) as int
        if delta > 32768:
            g_cam_zoom = g_cam_zoom * 1.1
        else:
            g_cam_zoom = g_cam_zoom / 1.1
        endofcode
    if msg == 256:
        let key = wParam as int
        if key >= 49 and key <= 54:
            g_mode = key - 49
            g_reset_req = 1
            update_title(hwnd)
            
        if key == 87:
            g_cam_y = g_cam_y + 3.0
        if key == 83:
            g_cam_y = g_cam_y - 3.0
        if key == 65:
            g_cam_x = g_cam_x - 3.0
        if key == 68:
            g_cam_x = g_cam_x + 3.0
        endofcode
        
    return DefWindowProcA(hwnd, msg, wParam, lParam)

def main() -> int:
    srand(42)
    let hInstance = GetModuleHandleA(0 as *char)
    
    let wc = {0} as WNDCLASSA
    wc.style = 3
    wc.lpfnWndProc = WindowProc as *void
    wc.hInstance = hInstance
    wc.lpszClassName = "FluxGLClass".data
    RegisterClassA((&wc) as *void)
    
    let hwnd = CreateWindowExA(0, "FluxGLClass".data, "".data, 0x10CA0000, 100, 100, g_width as int, g_height as int, 0 as *void, 0 as *void, hInstance, 0 as *void)
    update_title(hwnd)
    
    let pfd = {0} as PIXELFORMATDESCRIPTOR
    pfd.nSize = (sizeof(PIXELFORMATDESCRIPTOR)) as u16
    pfd.nVersion = 1
    pfd.dwFlags = 37
    pfd.iPixelType = 0
    pfd.cColorBits = 32
    pfd.cDepthBits = 24
    
    let hdc = GetDC(hwnd)
    let format = ChoosePixelFormat(hdc, (&pfd) as *void)
    SetPixelFormat(hdc, format, (&pfd) as *void)
    let hglrc = wglCreateContext(hdc)
    wglMakeCurrent(hdc, hglrc)
    
    let particles = bump(sizeof(Particle) * 2000) as *Particle
    let springs = bump(sizeof(Spring) * 1000) as *Spring
    
    let msg = {0} as MSG
    let running = true
    
    while running:
        while PeekMessageA((&msg) as *void, 0 as *void, 0, 0, 1) != 0:
            if msg.message == 18:
                running = false
            TranslateMessage((&msg) as *void)
            DispatchMessageA((&msg) as *void)
            
        if not running:
            break
            
        if g_reset_req == 1:
            init_scene(particles, springs)
            g_reset_req = 0
            
        update_physics(particles, springs, 0.016)
        render(particles, springs)
        
        SwapBuffers(hdc)
        Sleep(16)
        
    endofcode