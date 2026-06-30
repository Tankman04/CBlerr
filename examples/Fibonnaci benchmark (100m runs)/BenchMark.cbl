extern def printf(fmt: *void, ...) -> int

let start_ticks = 0 as int64
let end_ticks = 0 as int64

def main() -> int:
    asm(".intel_syntax noprefix\nrdtsc\nshl rdx, 32\nor rax, rdx\nmov start_ticks[rip], rax\n.att_syntax")
    
    iter: int = 0
    total_sum: int64 = 0
    mod_iter: int = 0
    
    while iter < 100000000:
        fib_res: int64 = mod_iter as int64
        if mod_iter > 1:
            a: int64 = 0
            b: int64 = 1
            i: int = mod_iter
            while i >= 5:
                a = a + b
                b = b + a
                a = a + b
                b = b + a
                i = i - 4
            while i > 1:
                b = b + a
                a = b - a
                i = i - 1
            fib_res = b
        
        total_sum = total_sum + fib_res
        
        mod_iter = mod_iter + 1
        if mod_iter == 41:
            mod_iter = 0
        iter = iter + 1
        
    asm(".intel_syntax noprefix\nrdtsc\nshl rdx, 32\nor rax, rdx\nmov end_ticks[rip], rax\n.att_syntax")
    
    total_ticks: int64 = end_ticks - start_ticks
    ticks_per_iter: int64 = total_ticks / 100000000
    
    printf("Check sum: %lld\n".data as *void, total_sum)
    printf("Total CPU Ticks: %lld\n".data as *void, total_ticks)
    printf("Ticks per iteration: %lld\n".data as *void, ticks_per_iter)
    
    endofcode
# so like i used that such dumb way to write code cause constant folding ruines everything so yeahh
