global_counter: int = 0

def add_numbers(a: int, b: int) -> int:
    return a + b

def factorial(n: int) -> int:
    if n <= 1:
        return 1
    return n * factorial(n - 1)

def tick_counter() -> int:
    global_counter += 1
    return global_counter

def sum_array(arr: *int, length: int) -> int:
    total: int = 0
    i: int = 0
    while i < length:
        total += arr[i]
        i += 1
    return total

def compute_circle_area(radius: f64) -> f64:
    pi: f64 = 3.141592653589793
    return pi * (radius * radius)