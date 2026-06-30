import ctypes
import os

lib_path = os.path.abspath("test_lib.dll")
print(f"Loading {lib_path}...")
cbl_lib = ctypes.CDLL(lib_path)

cbl_lib.add_numbers.argtypes = [ctypes.c_int, ctypes.c_int]
cbl_lib.add_numbers.restype = ctypes.c_int
res_add = cbl_lib.add_numbers(10, 32)
print(f"add_numbers(10, 32) = {res_add} (Expected: 42)")

cbl_lib.factorial.argtypes = [ctypes.c_int]
cbl_lib.factorial.restype = ctypes.c_int
res_fact = cbl_lib.factorial(5)
print(f"factorial(5) = {res_fact} (Expected: 120)")

cbl_lib.tick_counter.restype = ctypes.c_int
print("tick_counter() x3:", [cbl_lib.tick_counter() for _ in range(3)], "(Expected: [1, 2, 3])")

cbl_lib.sum_array.argtypes = [ctypes.POINTER(ctypes.c_int), ctypes.c_int]
cbl_lib.sum_array.restype = ctypes.c_int

nums = [10, 20, 30, 40, 50]
arr_type = ctypes.c_int * len(nums)
c_arr = arr_type(*nums)

res_sum = cbl_lib.sum_array(c_arr, len(nums))
print(f"sum_array([10,20,30,40,50]) = {res_sum} (Expected: 150)")

cbl_lib.compute_circle_area.argtypes = [ctypes.c_double]
cbl_lib.compute_circle_area.restype = ctypes.c_double
res_area = cbl_lib.compute_circle_area(10.0)
print(f"compute_circle_area(10.0) = {res_area:.4f} (Expected: 314.1593)")
