import sys
import os
import subprocess
import tempfile
import re
import platform
import time
from pathlib import Path
from typing import List, Optional, Tuple, Dict, Any
from collections import deque
import math

def is_gui_app_code(source_code: str) -> bool:
    clean = re.sub(r'//.*|/\*.*?\*/|"(?:\\.|[^"\\])*"', '', source_code, flags=re.DOTALL).lower()
    gui_calls = ["winmain", "windowproc", "createwindow", "dispatchmessage", "setwindowcompositionattribute"]
    return any(x in clean for x in gui_calls)

def is_packable_code(source_code: str) -> bool:
    if len(source_code) > 65536: 
        return False
    return True

def fold_constants(node: Any, debugger: Any = None) -> Any:
    if isinstance(node, (list, tuple)):
        if isinstance(node, list):
            for i in range(len(node)):
                node[i] = fold_constants(node[i], debugger)
        elif isinstance(node, tuple):
            node = tuple(fold_constants(x, debugger) for x in node)

    if not hasattr(node, '__dict__'):
        return node

    for k, v in vars(node).items():
        if isinstance(v, (list, tuple)) or hasattr(v, '__dict__'):
            setattr(node, k, fold_constants(v, debugger))

    try:
        from core.flux_ast import BinaryOp, Literal, Call, ArrayLiteral, IfStmt
        cname = node.__class__.__name__
        
        if cname == 'IfStmt' and isinstance(node.condition, Literal):
            if node.condition.value in (0, False, 0.0):
                node.then_body = []
            else:
                node.else_body = []
                
        if cname == 'Call':
            fname = node.func_name if isinstance(node.func_name, str) else getattr(node.func_name, 'name', None)
            if fname == 'len' and node.args and len(node.args) == 1:
                arg = node.args[0]
                if isinstance(arg, Literal) and isinstance(arg.value, str):
                    return Literal(len(arg.value), 'int') 
                elif isinstance(arg, ArrayLiteral):
                    return Literal(len(arg.elements), 'int')
            
            if fname in ('sin', 'cos', 'tan', 'sqrt', 'ceil', 'floor', 'abs', 'fabs', 'exp', 'log') and node.args and len(node.args) == 1:
                arg = node.args[0]
                if isinstance(arg, Literal) and arg.type in ('int', 'float', 'f32', 'f64', 'i32', 'i64'):
                    try:
                        val = float(arg.value)
                        res = None
                        if fname == 'sin': res = math.sin(val)
                        elif fname == 'cos': res = math.cos(val)
                        elif fname == 'tan': res = math.tan(val)
                        elif fname == 'sqrt': res = math.sqrt(val)
                        elif fname == 'ceil': res = math.ceil(val)
                        elif fname == 'floor': res = math.floor(val)
                        elif fname in ('abs', 'fabs'): res = abs(val)
                        elif fname == 'exp': res = math.exp(val)
                        elif fname == 'log' and val > 0: res = math.log(val)
                        
                        if res is not None:
                            return Literal(res, 'float')
                    except Exception: pass

        if cname == 'BinaryOp':
            if isinstance(node.left, Literal) and isinstance(node.right, Literal):
                try:
                    l_val = node.left.value
                    r_val = node.right.value
                    if node.left.type in ('int', 'float', 'i32', 'f32', 'f64', 'int64') and node.right.type in ('int', 'float', 'i32', 'f32', 'f64', 'int64'):
                        res = None
                        op = node.op
                        if op == '+': res = l_val + r_val
                        elif op == '-': res = l_val - r_val
                        elif op == '*': res = l_val * r_val
                        elif op == '/': 
                            if r_val == 0:
                                if debugger: debugger.log_error(f"Constant folding error: Division by zero")
                                return node
                            if isinstance(l_val, int) and isinstance(r_val, int):
                                res = l_val // r_val
                            else:
                                res = l_val / r_val
                        elif op == '%': 
                            if r_val == 0:
                                if debugger: debugger.log_error(f"Constant folding error: Modulo by zero")
                                return node
                            res = l_val % r_val
                        elif op == '**': res = l_val ** r_val
                        elif op == '&' and isinstance(l_val, int) and isinstance(r_val, int): res = l_val & r_val
                        elif op == '|' and isinstance(l_val, int) and isinstance(r_val, int): res = l_val | r_val
                        elif op == '^' and isinstance(l_val, int) and isinstance(r_val, int): res = l_val ^ r_val
                        elif op == '<<' and isinstance(l_val, int) and isinstance(r_val, int): res = l_val << r_val
                        elif op == '>>' and isinstance(l_val, int) and isinstance(r_val, int): res = l_val >> r_val

                        if res is not None:
                            t = 'float' if isinstance(res, float) else 'int'
                            return Literal(res, t)
                except Exception:
                    pass
    except: pass
    return node

def run_dce(ast: Any, is_lib: bool = False) -> Any:
    if is_lib:
        return ast
        
    if not hasattr(ast, 'functions') or not hasattr(ast, 'global_vars'):
        return ast
        
    func_map = {f.name: f for f in ast.functions}
    global_map = {g.name: g for g in ast.global_vars}
    
    reachable_funcs = set()
    reachable_globals = set()
    roots = ['main', 'WinMain', 'CblerrStartup', 'WindowProc']
    
    for f in ast.functions:
        if getattr(f, 'is_extern', False) and f.name not in roots:
            roots.append(f.name)
            
    has_root = any(r in func_map for r in roots)
    if not has_root:
        return ast
        
    worklist = deque() 
    for r in roots:
        if r in func_map:
            reachable_funcs.add(r)
            worklist.append(func_map[r])
            
    def visit(node):
        if isinstance(node, (list, tuple)):
            for n in node: visit(n)
            return
        if type(node) in (int, float, str, bool, type(None)): 
            return
        if not hasattr(node, '__dict__'): return
            
        node_type = node.__class__.__name__
        
        if node_type == 'Call':
            fname = node.func_name if isinstance(node.func_name, str) else getattr(node.func_name, 'name', None)
            if fname and fname in func_map and fname not in reachable_funcs:
                reachable_funcs.add(fname)
                worklist.append(func_map[fname])
                
        elif node_type == 'Variable':
            vname = node.name
            if vname in global_map and vname not in reachable_globals:
                reachable_globals.add(vname)
                worklist.append(global_map[vname])
            if vname in func_map and vname not in reachable_funcs:
                reachable_funcs.add(vname)
                worklist.append(func_map[vname])
                
        elif node_type == 'FieldAccess':
            if node.obj.__class__.__name__ == 'Variable':
                mangled_name = f"{node.obj.name}__{node.field}"
                if mangled_name in global_map and mangled_name not in reachable_globals:
                    reachable_globals.add(mangled_name)
                    worklist.append(global_map[mangled_name])
                if mangled_name in func_map and mangled_name not in reachable_funcs:
                    reachable_funcs.add(mangled_name)
                    worklist.append(func_map[mangled_name])
                
        for k, v in vars(node).items():
            if k == 'resolved_type': continue
            visit(v)
            
    while worklist:
        curr = worklist.popleft()
        visit(curr)
        
    ast.functions = [f for f in ast.functions if f.name in reachable_funcs]
    ast.global_vars = [g for g in ast.global_vars if g.name in reachable_globals]
    return ast

core_path = Path(__file__).parent.parent / "core"
if getattr(sys, 'frozen', False):
    try:
        meipass = Path(sys._MEIPASS)
        core_path = meipass / "core"
        sys.path.insert(0, str(meipass.resolve()))
    except Exception:
        core_path = Path(__file__).parent.parent / "core"
        sys.path.insert(0, str(core_path.parent.resolve()))
else:
    sys.path.insert(0, str(Path(__file__).parent.parent.resolve()))

import importlib
import traceback

try:
    for _name in ("lexer", "flux_parser", "flux_ast", "type_checker"):
        try:
            core_mod = importlib.import_module(f"core.{_name}")
            sys.modules[_name] = core_mod
        except Exception:
            traceback.print_exc()
            raise
except Exception:
    traceback.print_exc()
    raise

from core.lexer import tokenize, TokenType
from core.flux_parser import parse, ParsingError
from core.type_checker import type_check, TypeCheckError
from core.flux_ast import (
    Program, FunctionDef, Return, BinaryOp, Variable, Literal,
    IfStmt, Assign, Compare, Call, WhileLoop, BreakStmt, ContinueStmt,
    StructDef, FieldAccess, ArrayAccess, ArrayLiteral, LogicalOp,
    PointerType, Dereference, InlineAsm, CastExpr, Decorator, ComptimeBlock,
    MatchStmt, Case, ForLoop, EnumDef, AddressOf, SizeOf, WalrusExpr, DeferStmt
)
from core.debugger import init_debugger, get_debugger, DebugLevel

class StaticMemoryAnalyzer:
    def __init__(self, debugger):
        self.debugger = debugger

    def report(self, msg, node):
        line = getattr(node, 'line', '?')
        self.debugger.log_warning(f"Memory Analyzer: {msg} (Line {line})")

    def analyze(self, ast):
        if not hasattr(ast, 'functions'): return ast
        for func in ast.functions:
            if not getattr(func, 'is_extern', False):
                self.analyze_func(func)
        return ast

    def analyze_func(self, func):
        states = {} 
        aliases = {}

        def get_root_alias(name):
            seen = set()
            while name in aliases and name not in seen:
                seen.add(name)
                name = aliases[name]
            return name

        def get_target_name(expr):
            if isinstance(expr, str): return expr
            if not expr: return None
            cname = expr.__class__.__name__
            if cname == 'Variable': return expr.name
            if cname == 'FieldAccess':
                obj = get_target_name(expr.obj)
                return f"{obj}.{expr.field}" if obj else None
            return None

        def visit_expr(expr):
            if not expr: return
            if isinstance(expr, (int, float, str, bool)): return
            cname = expr.__class__.__name__
            
            if cname == 'Variable':
                root = get_root_alias(expr.name)
                if states.get(root) == 'FREED':
                    self.report(f"Use-After-Free: Variable '{expr.name}' used after being freed.", expr)
            
            elif cname in ('FieldAccess', 'Dereference'):
                base_name = get_target_name(expr.obj if cname == 'FieldAccess' else expr.ptr)
                if base_name:
                    root = get_root_alias(base_name)
                    if states.get(root) == 'NULL':
                        self.report(f"NPE (Null Pointer Exception): Attempt to dereference '{base_name}' which is NULL.", expr)
                    elif states.get(root) == 'FREED':
                        self.report(f"Use-After-Free: Dereferencing freed pointer '{base_name}'.", expr)
                if cname == 'FieldAccess': visit_expr(expr.obj)
                else: visit_expr(expr.ptr)

            elif cname == 'Call':
                fname = expr.func_name if isinstance(expr.func_name, str) else getattr(expr.func_name, 'name', '')
                if fname == 'free' and expr.args:
                    arg_name = get_target_name(expr.args[0])
                    if arg_name:
                        root = get_root_alias(arg_name)
                        state = states.get(root)
                        if state == 'BUMPED':
                            self.report(f"Arena Corruption: Calling free() on pointer '{arg_name}' allocated by bump()! Bump memory cannot be freed individually.", expr)
                        elif state == 'FREED':
                            self.report(f"Double Free: Pointer '{arg_name}' is already freed.", expr)
                        states[root] = 'FREED'
                        for k in list(states.keys()):
                            if get_root_alias(k) == root:
                                states[k] = 'FREED'
                else:
                    for arg in (expr.args or []): visit_expr(arg)

            elif cname in ('BinaryOp', 'Compare', 'LogicalOp', 'Assign', 'WalrusExpr'):
                if hasattr(expr, 'left'): visit_expr(expr.left)
                if hasattr(expr, 'right'): visit_expr(expr.right)
                if hasattr(expr, 'value'): visit_expr(expr.value)
                if hasattr(expr, 'target') and cname == 'WalrusExpr': visit_expr(expr.target)
            elif cname == 'ArrayAccess':
                visit_expr(expr.arr)
                visit_expr(expr.index)
            elif cname in ('AddressOf', 'SizeOf', 'CastExpr'):
                if hasattr(expr, 'expr'): visit_expr(expr.expr)

        def visit_stmt(stmt):
            if not stmt: return
            cname = stmt.__class__.__name__
            
            if cname == 'Assign':
                t_name = get_target_name(stmt.target)
                val_cname = stmt.value.__class__.__name__ if stmt.value else None
                
                if t_name:
                    root = get_root_alias(t_name)
                    if val_cname == 'Literal' and stmt.value.value == 0:
                        states[root] = 'NULL'
                    elif val_cname == 'CastExpr' and stmt.value.expr.__class__.__name__ == 'Literal' and stmt.value.expr.value == 0:
                        states[root] = 'NULL'
                    elif val_cname == 'Call':
                        fname = stmt.value.func_name if isinstance(stmt.value.func_name, str) else getattr(stmt.value.func_name, 'name', '')
                        if fname == 'malloc':
                            if states.get(root) == 'ALLOCATED':
                                self.report(f"Memory Leak: '{t_name}' reassigned to a new malloc without freeing.", stmt)
                            states[root] = 'ALLOCATED'
                        elif fname == 'bump':
                            states[root] = 'BUMPED'
                    elif val_cname == 'Variable':
                        aliases[t_name] = stmt.value.name
                        
                visit_expr(stmt.value)
                    
            elif cname == 'Call': visit_expr(stmt)
            elif cname == 'Return':
                visit_expr(stmt.value)
                ret_name = get_root_alias(get_target_name(stmt.value)) if stmt.value else None
                ret_aliases = {k for k in states if get_root_alias(k) == ret_name}
                ret_aliases.add(ret_name)
                for var, state in states.items():
                    if state == 'ALLOCATED' and var not in ret_aliases:
                        self.report(f"Memory Leak: '{var}' is malloc'd but not freed before return.", stmt)
            elif cname == 'IfStmt':
                visit_expr(stmt.condition)
                for s in (stmt.then_body or []): visit_stmt(s)
                for s in (stmt.else_body or []): visit_stmt(s)
            elif cname in ('WhileLoop', 'ForLoop'):
                if hasattr(stmt, 'condition'): visit_expr(stmt.condition)
                if hasattr(stmt, 'init'): visit_stmt(stmt.init)
                if hasattr(stmt, 'iter_expr'): visit_expr(stmt.iter_expr)
                for s in (stmt.body or []): visit_stmt(s)
            elif cname == 'MatchStmt':
                visit_expr(stmt.expr)
                for case in stmt.cases:
                    for s in case.body: visit_stmt(s)
            elif cname == 'DeferStmt':
                for s in stmt.body: visit_stmt(s)

        if func.body:
            for stmt in func.body:
                visit_stmt(stmt)

class CBLCodeEmitter:
    def __init__(self, target: str = "windows", module_name: str = "cblerr_module", source_filename: str = "", link_mode: Optional[str] = None, is_gui_app: bool = False):
        target_lower = target.lower()
        self.is_dll = (target_lower == "winlib")
        self.is_scr = (target_lower in ("winsaver", "screensaver"))
        if target_lower == "wasm":
            self.target = "wasm"
        else:
            self.target = "windows" if (self.is_dll or self.is_scr or target_lower == "windows") else target_lower
            
        self.module_name = module_name
        self.source_filename = source_filename
        self.link_mode = link_mode
        self.is_gui_app = is_gui_app
        self.needs_utf8 = False

        self.code_lines: List[str] = []
        self.indent_level = 0
        self.header_signatures: List[str] = []

        self.string_pool: Dict[str, str] = {}
        self.dynamic_globals: List[Tuple[str, Any]] = []
        self.global_vars: Dict[str, Any] = {}
        self.local_vars_stack: List[Dict[str, str]] = []
        self.used_externs = set()
        self.current_function = None
        
        self.defer_scopes: List[List[Any]] = []
        self.loop_depths: List[int] = []

        self.win_critical_externs = {"LoadLibraryA", "GetProcAddress", "ExitProcess", "GetStdHandle", "ReadFile", "WriteFile"}
        
        self.win_msvcrt_registry = {
            "printf": ("int", "(const char*, ...)"),
            "sprintf": ("int", "(char*, const char*, ...)"), 
            "puts": ("int", "(const char*)"),
            "scanf": ("int", "(const char*, ...)"),
            
            "_kbhit": ("int", "(void)"),
            "_getch": ("int", "(void)"),
            "kbhit": ("int", "(void)"),
            "getch": ("int", "(void)"),
            "getchar": ("int", "(void)"),
            "putchar": ("int", "(int)"),
            
            "fopen": ("void*", "(const char*, const char*)"),
            "fclose": ("int", "(void*)"),
            "fread": ("size_t", "(void*, size_t, size_t, void*)"),
            "fwrite": ("size_t", "(const void*, size_t, size_t, void*)"),
            "fseek": ("int", "(void*, long, int)"),
            "ftell": ("long", "(void*)"),
            
            "system": ("int", "(const char*)"),
            "exit": ("void", "(int)")
        }

    def emit_line(self, line: str = ""):
        if line:
            self.code_lines.append("    " * self.indent_level + line)
        else:
            self.code_lines.append("")

    def _escape_string(self, s: str) -> str:
        b = s.encode('utf-8')
        res = []
        for byte in b:
            if byte == 92: res.append('\\\\')
            elif byte == 34: res.append('\\"')
            elif byte == 10: res.append('\\n')
            elif byte == 13: res.append('\\r')
            elif byte == 9: res.append('\\t')
            elif 32 <= byte <= 126: res.append(chr(byte))
            else: res.append(f"\\{byte:03o}")
        return ''.join(res)

    def _get_local_c_type(self, var_name: str) -> Optional[str]:
        if self.local_vars_stack and var_name in self.local_vars_stack[-1]:
            return self.local_vars_stack[-1][var_name]
        if var_name in self.global_vars:
            g_var = self.global_vars[var_name]
            if isinstance(g_var.var_type, str):
                return self._get_c_type(g_var.var_type)
            elif hasattr(g_var, 'var_type') and getattr(g_var.var_type, 'name', None) == 'array':
                inner = g_var.var_type.args[0] if getattr(g_var.var_type, 'args', None) else 'int'
                return f"{self._get_c_type(inner)}*"
        return None

    def _collect_dependencies(self, node: Any):
        if isinstance(node, list):
            for n in node:
                self._collect_dependencies(n)
            return
        if not hasattr(node, '__dict__'):
            return

        if isinstance(node, FunctionDef) and getattr(node, 'is_extern', False):
            self.used_externs.add(node.name)

        if isinstance(node, Literal) and isinstance(node.value, str):
            val = node.value
            if val not in self.string_pool:
                self.string_pool[val] = f"__str_const_{len(self.string_pool)}"

        if isinstance(node, Call):
            fname = node.func_name if isinstance(node.func_name, str) else getattr(node.func_name, 'name', None)
            if fname:
                if fname == 'print':
                    if not getattr(node, 'args', None):
                        fast_val = "" if self.target == 'wasm' else "\n"
                        if fast_val not in self.string_pool:
                            self.string_pool[fast_val] = f"__str_const_{len(self.string_pool)}"
                        setattr(node, '_is_fast_print', fast_val)
                        self.used_externs.add('Cblerr_print_fast')
                        if self.target == 'windows':
                            self.used_externs.add('WriteConsoleA')
                            self.used_externs.add('GetStdHandle')
                        return
                    
                    self.used_externs.add('Cblerr_print_string')
                    if self.target == 'windows':
                        self.used_externs.add('WriteConsoleA')
                        self.used_externs.add('GetStdHandle')
                else:
                    self.used_externs.add(fname)
                    
        elif isinstance(node, Compare):
            left_t = getattr(node.left, 'resolved_type', getattr(node.left, 'type', None))
            right_t = getattr(node.right, 'resolved_type', getattr(node.right, 'type', None))
            if left_t == 'str' or right_t == 'str':
                self.used_externs.add('flux_string_eq')

        for k, v in vars(node).items():
            if k == 'resolved_type': continue
            if isinstance(v, (list, tuple)) or hasattr(v, '__dict__'):
                self._collect_dependencies(v)

    def generate(self, program: Program) -> str:
        self.program = program
        self.imported_modules = set()
        
        for imp in getattr(program, 'imports', []):
            if imp.__class__.__name__ == 'ImportStmt':
                self.imported_modules.add(imp.module_name)
                
        self._collect_dependencies(program)
        
        self.needs_utf8 = any(ord(c) > 127 for val in self.string_pool.keys() for c in val)

        self._emit_prelude()
        self._emit_runtime()

        if program.structs:
            for struct_def in program.structs:
                if struct_def.__class__.__name__ == 'EnumDef': continue
                self.emit_line(f"struct {struct_def.name};")
            self.emit_line()
            for struct_def in program.structs:
                if struct_def.__class__.__name__ == 'EnumDef': self._generate_enum(struct_def)
                else: self._generate_struct_def(struct_def)
            self.emit_line()

        if self.string_pool:
            for val, name in self.string_pool.items():
                escaped = self._escape_string(val)
                byte_len = len(val.encode('utf-8'))
                self.emit_line(f'static const string {name} = {{(char*)"{escaped}", {byte_len}}};')
            self.emit_line()

        if program.global_vars:
            for global_var in program.global_vars:
                self._generate_global_var(global_var)
            self.emit_line()

        runtime_provided = {"sys_write", "sys_mmap", "sys_munmap", "Cblerr_print_string", "Cblerr_print_fast", "flux_string_eq"}
        runtime_provided.update({"malloc", "free", "bump", "rand", "srand", "time", "clock"})
        runtime_provided.update({'sin', 'cos', 'tan', 'pow', 'sqrt', 'asin', 'acos', 'atan', 'atan2', 'log', 'exp', 'floor', 'ceil', 'fmod', 'abs', 'fabs'})
        runtime_provided.update({'memset', 'memcpy', 'memmove', 'memcmp', 'strcmp', 'strlen'})
        runtime_provided.add("wasm_print")

        if program.functions:
            for func_def in program.functions:
                if getattr(func_def, 'is_extern', False):
                    if self.target == 'windows' and func_def.name in self.win_msvcrt_registry: continue
                    if func_def.name in runtime_provided: continue
                    sig = self._generate_function_signature(func_def)
                    self.emit_line(f"{sig};")
            for func_def in program.functions:
                if getattr(func_def, 'is_extern', False): continue
                sig = self._generate_function_signature(func_def)
                self.header_signatures.append(f"extern {sig};")
                self.emit_line(f"{sig};")
            self.emit_line()
            for func_def in program.functions:
                if getattr(func_def, 'is_extern', False): continue
                self._generate_function_def(func_def)
                self.emit_line()

        self._emit_entry_point()

        return "\n".join(self.code_lines)

    def _emit_prelude(self):
        self.emit_line("typedef signed char int8_t;")
        self.emit_line("typedef short int16_t;")
        self.emit_line("typedef int int32_t;")
        self.emit_line("typedef long long int64_t;")
        self.emit_line("typedef unsigned char uint8_t;")
        self.emit_line("typedef unsigned short uint16_t;")
        self.emit_line("typedef unsigned int uint32_t;")
        self.emit_line("typedef unsigned long long uint64_t;")
        self.emit_line("#if defined(__LP64__) || defined(_WIN64) || defined(__wasm64__)")
        self.emit_line("typedef unsigned long long size_t;")
        self.emit_line("#else")
        self.emit_line("typedef unsigned int size_t;")
        self.emit_line("#endif")
        self.emit_line("#define bool _Bool")
        self.emit_line("#define true 1")
        self.emit_line("#define false 0")
        self.emit_line("#define NULL ((void*)0)")
        self.emit_line("#define CBL_UNLIKELY(x) __builtin_expect(!!(x), 0)")
        self.emit_line()
        self.emit_line("typedef struct {")
        self.emit_line("    char* data;")
        self.emit_line("    long length;")
        self.emit_line("} string;")
        self.emit_line("typedef string flux_string;")
        self.emit_line()

    def _emit_runtime(self):
        all_user_funcs = {f.name for f in self.program.functions} if hasattr(self, 'program') and hasattr(self.program, 'functions') else set()
        user_impls = {f.name for f in self.program.functions if not getattr(f, 'is_extern', False)} if hasattr(self, 'program') and hasattr(self.program, 'functions') else set()

        runtime_provided = {"sys_write", "sys_mmap", "sys_munmap", "Cblerr_print_string", "Cblerr_print_fast", "flux_string_eq"}
        runtime_provided.update({"malloc", "free", "bump", "rand", "srand", "time", "clock"})
        runtime_provided.update({'sin', 'cos', 'tan', 'pow', 'sqrt', 'asin', 'acos', 'atan', 'atan2', 'log', 'exp', 'floor', 'ceil', 'fmod', 'abs', 'fabs'})
        runtime_provided.update({'memset', 'memcpy', 'memmove', 'memcmp', 'strcmp', 'strlen'})
        runtime_provided.add("wasm_print")

        if self.target == "windows":
            if "LoadLibraryA" not in all_user_funcs:
                self.emit_line("extern void* __stdcall LoadLibraryA(const char*);")
            if "GetModuleHandleA" not in all_user_funcs:
                self.emit_line("extern void* __stdcall GetModuleHandleA(const char*);") 
            if "GetProcAddress" not in all_user_funcs:
                self.emit_line("extern void* __stdcall GetProcAddress(void*, const char*);")
            if "ExitProcess" not in all_user_funcs:
                self.emit_line("extern void __stdcall ExitProcess(int32_t);")
                
            if not self.is_dll and not self.is_gui_app and getattr(self, 'needs_utf8', False):
                if "SetConsoleOutputCP" not in all_user_funcs:
                    self.emit_line("extern int32_t __stdcall SetConsoleOutputCP(uint32_t);")
            
            if 'WriteConsoleA' in self.used_externs:
                if "GetStdHandle" not in all_user_funcs:
                    self.emit_line("extern void* __stdcall GetStdHandle(int32_t);")
                if "WriteConsoleA" not in all_user_funcs:
                    self.emit_line("extern int32_t __stdcall WriteConsoleA(void*, const void*, int32_t, void*, void*);")
                self.emit_line("static void* cbl_stdout_handle = ((void*)0);")
            
            self.emit_line()
            
            win_custom_funcs = {'malloc', 'free', 'bump', 'rand', 'srand', 'time', 'clock'}
            used_win_custom = [name for name in win_custom_funcs if name in self.used_externs]
            
            if used_win_custom:
                if 'bump' in used_win_custom and "VirtualAlloc" not in all_user_funcs:
                    self.emit_line("extern void* __stdcall VirtualAlloc(void*, size_t, uint32_t, uint32_t);")
                
                if ('malloc' in used_win_custom or 'free' in used_win_custom):
                    if "GetProcessHeap" not in all_user_funcs:
                        self.emit_line("extern void* __stdcall GetProcessHeap(void);")
                    if "HeapAlloc" not in all_user_funcs:
                        self.emit_line("extern void* __stdcall HeapAlloc(void*, uint32_t, size_t);")
                    if "HeapFree" not in all_user_funcs:
                        self.emit_line("extern int32_t __stdcall HeapFree(void*, uint32_t, void*);")

                if "QueryPerformanceCounter" not in all_user_funcs:
                    self.emit_line("extern int __stdcall QueryPerformanceCounter(int64_t*);")
                if "QueryPerformanceFrequency" not in all_user_funcs:
                    self.emit_line("extern int __stdcall QueryPerformanceFrequency(int64_t*);")
                if "GetSystemTimeAsFileTime" not in all_user_funcs:
                    self.emit_line("extern void __stdcall GetSystemTimeAsFileTime(void*);")
                
                self.emit_line()
                for func in used_win_custom:
                    self.emit_line(f"#define {func} cbl_{func}")
                
                if 'bump' in used_win_custom:
                    self.emit_line("static char* cbl_arena_base = 0;")
                    self.emit_line("static size_t cbl_arena_offset = 0;")
                    self.emit_line("static inline void* cbl_bump(size_t size) {")
                    self.emit_line("    if (!cbl_arena_base) cbl_arena_base = (char*)VirtualAlloc(0, 1024 * 1024 * 1024, 0x3000, 0x04);")
                    self.emit_line("    size_t align = (size + 7) & ~7;")
                    self.emit_line("    void* ptr = cbl_arena_base + cbl_arena_offset;")
                    self.emit_line("    cbl_arena_offset += align;")
                    self.emit_line("    return ptr;")
                    self.emit_line("}")

                if 'malloc' in used_win_custom:
                    self.emit_line("static inline void* cbl_malloc(size_t size) {")
                    self.emit_line("    return HeapAlloc(GetProcessHeap(), 0, size);")
                    self.emit_line("}")
                if 'free' in used_win_custom:
                    self.emit_line("static inline void cbl_free(void* ptr) {")
                    self.emit_line("    if (ptr) HeapFree(GetProcessHeap(), 0, ptr);")
                    self.emit_line("}")
                
                if 'rand' in used_win_custom or 'srand' in used_win_custom:
                    self.emit_line("static uint32_t cbl_rand_state = 2463534242;")
                    if 'srand' in used_win_custom:
                        self.emit_line("static inline void cbl_srand(uint32_t seed) { cbl_rand_state = seed | 1; }")
                    if 'rand' in used_win_custom:
                        self.emit_line("static inline int cbl_rand(void) {")
                        self.emit_line("    uint32_t x = cbl_rand_state;")
                        self.emit_line("    x ^= x << 13; x ^= x >> 17; x ^= x << 5;")
                        self.emit_line("    cbl_rand_state = x;")
                        self.emit_line("    return (int)(x & 0x7FFFFFFF);")
                        self.emit_line("}")
                
                if 'clock' in used_win_custom:
                    self.emit_line("static int64_t cbl_timer_freq = 0;")
                    self.emit_line("static int64_t cbl_timer_start = 0;")
                    self.emit_line("static inline int cbl_clock(void) {")
                    self.emit_line("    if (cbl_timer_freq == 0) {")
                    self.emit_line("        QueryPerformanceFrequency(&cbl_timer_freq);")
                    self.emit_line("        QueryPerformanceCounter(&cbl_timer_start);")
                    self.emit_line("    }")
                    self.emit_line("    int64_t current;")
                    self.emit_line("    QueryPerformanceCounter(&current);")
                    self.emit_line("    return (int)((current - cbl_timer_start) * 1000 / cbl_timer_freq);")
                    self.emit_line("}")
                    
                if 'time' in used_win_custom:
                    self.emit_line("static inline int64_t cbl_time(void* dummy) {")
                    self.emit_line("    int64_t file_time;")
                    self.emit_line("    GetSystemTimeAsFileTime(&file_time);")
                    self.emit_line("    return (file_time - 116444736000000000LL) / 10000000LL;")
                    self.emit_line("}")

            used_msvcrt = [name for name in self.win_msvcrt_registry if name in self.used_externs]
            if used_msvcrt:
                self.emit_line("void* cbl_hMsvcrt = NULL;")
                for name in used_msvcrt:
                    ret, args = self.win_msvcrt_registry[name]
                    self.emit_line(f"typedef {ret} (__cdecl *PFN_win_{name}){args};")
                    self.emit_line(f"PFN_win_{name} cbl_win_{name} = NULL;")
                    self.emit_line(f"#define {name} cbl_win_{name}")
                
                self.emit_line("static inline void CblerrInitMsvcrt(void) {")
                self.emit_line('    cbl_hMsvcrt = GetModuleHandleA((void*)"msvcrt.dll");')
                self.emit_line('    if (!cbl_hMsvcrt) cbl_hMsvcrt = LoadLibraryA((void*)"msvcrt.dll");')
                self.emit_line('    if (cbl_hMsvcrt) {')
                for name in used_msvcrt:
                    self.emit_line(f'        cbl_win_{name} = (PFN_win_{name})GetProcAddress(cbl_hMsvcrt, (void*)"{name}");')
                self.emit_line("    }")
                self.emit_line("}")
            else:
                self.emit_line("static inline void CblerrInitMsvcrt(void) {}")
                
            self.emit_line("int _fltused = 0;")
            self.emit_line("void __main(void) {} // FIX FOR GCC/MinGW cus it's gonna cry and send me bloated code")
            
            if 'Cblerr_print_string' in self.used_externs and "Cblerr_print_string" not in user_impls:
                self.emit_line("static inline void Cblerr_print_string(string s) {")
                self.emit_line("    if (!cbl_stdout_handle) cbl_stdout_handle = GetStdHandle((int32_t)-11);")
                self.emit_line("    if (cbl_stdout_handle && cbl_stdout_handle != (void*)-1) {")
                self.emit_line("        int32_t written;")
                self.emit_line("        WriteConsoleA(cbl_stdout_handle, (void*)s.data, (int32_t)s.length, &written, NULL);")
                self.emit_line('        WriteConsoleA(cbl_stdout_handle, (void*)"\\n", 1, &written, NULL);')
                self.emit_line("    }")
                self.emit_line("}")
                
            if 'Cblerr_print_fast' in self.used_externs and "Cblerr_print_fast" not in user_impls:
                self.emit_line("static inline void Cblerr_print_fast(string s) {")
                self.emit_line("    if (!cbl_stdout_handle) cbl_stdout_handle = GetStdHandle((int32_t)-11);")
                self.emit_line("    if (cbl_stdout_handle && cbl_stdout_handle != (void*)-1) {")
                self.emit_line("        int32_t written;")
                self.emit_line("        WriteConsoleA(cbl_stdout_handle, (void*)s.data, (int32_t)s.length, &written, NULL);")
                self.emit_line("    }")
                self.emit_line("}")
                
        elif self.target == "linux":
            self.emit_line("#if defined(__x86_64__)")
            self.emit_line("#define CBL_SYS_WRITE 1")
            self.emit_line("#define CBL_SYS_MMAP 9")
            self.emit_line("#define CBL_SYS_MUNMAP 11")
            self.emit_line("#elif defined(__aarch64__)")
            self.emit_line("#define CBL_SYS_WRITE 64")
            self.emit_line("#define CBL_SYS_MMAP 222")
            self.emit_line("#define CBL_SYS_MUNMAP 215")
            self.emit_line("#endif")

            if any(x in self.used_externs for x in ['print', 'Cblerr_print_string', 'Cblerr_print_fast', 'fprintf', 'sys_write']):
                if "sys_write" not in user_impls:
                    self.emit_line("static inline long sys_write(long fd, const void *buf, unsigned long count) {")
                    self.emit_line("#if defined(__x86_64__)")
                    self.emit_line("    long ret;")
                    self.emit_line('    __asm__ volatile ("syscall" : "=a"(ret) : "a"(CBL_SYS_WRITE), "D"(fd), "S"(buf), "d"(count) : "rcx", "r11", "memory");')
                    self.emit_line("    return ret;")
                    self.emit_line("#elif defined(__aarch64__)")
                    self.emit_line("    register long x8 __asm__(\"x8\") = CBL_SYS_WRITE;")
                    self.emit_line("    register long x0 __asm__(\"x0\") = fd;")
                    self.emit_line("    register long x1 __asm__(\"x1\") = (long)buf;")
                    self.emit_line("    register long x2 __asm__(\"x2\") = count;")
                    self.emit_line('    __asm__ volatile ("svc #0" : "=r"(x0) : "r"(x8), "r"(x0), "r"(x1), "r"(x2) : "memory");')
                    self.emit_line("    return x0;")
                    self.emit_line("#else")
                    self.emit_line("    extern long write(int, const void*, unsigned long);")
                    self.emit_line("    return write((int)fd, buf, count);")
                    self.emit_line("#endif")
                    self.emit_line("}")

            if any(x in self.used_externs for x in ['malloc', 'free', 'bump']):
                if "sys_mmap" not in user_impls:
                    self.emit_line("static inline void* sys_mmap(void *addr, unsigned long length, long prot, long flags, long fd, long offset) {")
                    self.emit_line("#if defined(__x86_64__)")
                    self.emit_line("    long ret;")
                    self.emit_line('    register long r10 __asm__("r10") = flags;')
                    self.emit_line('    register long r8 __asm__("r8") = fd;')
                    self.emit_line('    register long r9 __asm__("r9") = offset;')
                    self.emit_line('    __asm__ volatile ("syscall" : "=a"(ret) : "a"(CBL_SYS_MMAP), "D"(addr), "S"(length), "d"(prot), "r"(r10), "r"(r8), "r"(r9) : "rcx", "r11", "memory");')
                    self.emit_line("    return (void*)ret;")
                    self.emit_line("#elif defined(__aarch64__)")
                    self.emit_line("    register long x8 __asm__(\"x8\") = CBL_SYS_MMAP;")
                    self.emit_line("    register long x0 __asm__(\"x0\") = (long)addr;")
                    self.emit_line("    register long x1 __asm__(\"x1\") = length;")
                    self.emit_line("    register long x2 __asm__(\"x2\") = prot;")
                    self.emit_line("    register long x3 __asm__(\"x3\") = flags;")
                    self.emit_line("    register long x4 __asm__(\"x4\") = fd;")
                    self.emit_line("    register long x5 __asm__(\"x5\") = offset;")
                    self.emit_line('    __asm__ volatile ("svc #0" : "=r"(x0) : "r"(x8), "r"(x0), "r"(x1), "r"(x2), "r"(x3), "r"(x4), "r"(x5) : "memory");')
                    self.emit_line("    return (void*)x0;")
                    self.emit_line("#else")
                    self.emit_line("    extern void* mmap(void*, unsigned long, int, int, int, long);")
                    self.emit_line("    return mmap(addr, length, (int)prot, (int)flags, (int)fd, offset);")
                    self.emit_line("#endif")
                    self.emit_line("}")

                if "sys_munmap" not in user_impls:
                    self.emit_line("static inline void sys_munmap(void *addr, unsigned long length) {")
                    self.emit_line("#if defined(__x86_64__)")
                    self.emit_line("    long ret;")
                    self.emit_line('    __asm__ volatile ("syscall" : "=a"(ret) : "a"(CBL_SYS_MUNMAP), "D"(addr), "S"(length) : "rcx", "r11", "memory");')
                    self.emit_line("#elif defined(__aarch64__)")
                    self.emit_line("    register long x8 __asm__(\"x8\") = CBL_SYS_MUNMAP;")
                    self.emit_line("    register long x0 __asm__(\"x0\") = (long)addr;")
                    self.emit_line("    register long x1 __asm__(\"x1\") = length;")
                    self.emit_line('    __asm__ volatile ("svc #0" : "=r"(x0) : "r"(x8), "r"(x0), "r"(x1) : "memory");')
                    self.emit_line("#else")
                    self.emit_line("    extern int munmap(void*, unsigned long);")
                    self.emit_line("    munmap(addr, length);")
                    self.emit_line("#endif")
                    self.emit_line("}")

                if 'bump' in self.used_externs:
                    self.emit_line("#define bump cbl_bump")
                    if "bump" not in user_impls:
                        self.emit_line("static char* cbl_arena_base = 0;")
                        self.emit_line("static size_t cbl_arena_offset = 0;")
                        self.emit_line("static inline void* cbl_bump(size_t size) {")
                        self.emit_line("    if (!cbl_arena_base) cbl_arena_base = (char*)sys_mmap(((void*)0), 1024 * 1024 * 1024, 3, 34, -1, 0);")
                        self.emit_line("    size_t align = (size + 7) & ~7;")
                        self.emit_line("    void* ptr = cbl_arena_base + cbl_arena_offset;")
                        self.emit_line("    cbl_arena_offset += align;")
                        self.emit_line("    return ptr;")
                        self.emit_line("}")

                if 'malloc' in self.used_externs or 'free' in self.used_externs:
                    self.emit_line("#define malloc cbl_malloc")
                    self.emit_line("#define free cbl_free")
                    
                    if "malloc" not in user_impls:
                        self.emit_line("static inline void* cbl_malloc(size_t size) {")
                        self.emit_line("    if (!size) return ((void*)0);")
                        self.emit_line("    size_t align = (size + sizeof(size_t) + 7) & ~7;")
                        self.emit_line("    size_t* ptr = (size_t*)sys_mmap(((void*)0), align, 3, 34, -1, 0);")
                        self.emit_line("    if (ptr == (void*)-1) return ((void*)0);")
                        self.emit_line("    *ptr = align;")
                        self.emit_line("    return (void*)(ptr + 1);")
                        self.emit_line("}")
                    if "free" not in user_impls:
                        self.emit_line("static inline void cbl_free(void* ptr) {")
                        self.emit_line("    if (!ptr) return;")
                        self.emit_line("    size_t* p = (size_t*)ptr - 1;")
                        self.emit_line("    sys_munmap(p, *p);")
                        self.emit_line("}")

            if 'Cblerr_print_string' in self.used_externs and "Cblerr_print_string" not in user_impls:
                self.emit_line("static inline void Cblerr_print_string(string s) {")
                self.emit_line("    sys_write(1, s.data, s.length);")
                self.emit_line('    sys_write(1, "\\n", 1);')
                self.emit_line("}")

            if 'Cblerr_print_fast' in self.used_externs and "Cblerr_print_fast" not in user_impls:
                self.emit_line("static inline void Cblerr_print_fast(string s) {")
                self.emit_line("    sys_write(1, s.data, s.length);")
                self.emit_line("}")

        elif self.target == "wasm":
            if 'bump' in self.used_externs:
                self.emit_line("#define bump cbl_bump")
                if "bump" not in user_impls:
                    self.emit_line("static size_t cbl_bump_offset = 0;")
                    self.emit_line("static inline void* cbl_bump(size_t size) {")
                    self.emit_line("    if (cbl_bump_offset == 0) cbl_bump_offset = __builtin_wasm_memory_size(0) * 65536;")
                    self.emit_line("    size_t align = (size + 7) & ~7;")
                    self.emit_line("    if (cbl_bump_offset + align > __builtin_wasm_memory_size(0) * 65536) {")
                    self.emit_line("        __builtin_wasm_memory_grow(0, ((cbl_bump_offset + align - __builtin_wasm_memory_size(0) * 65536) + 65535) / 65536);")
                    self.emit_line("    }")
                    self.emit_line("    void* ptr = (char*)0 + cbl_bump_offset;")
                    self.emit_line("    cbl_bump_offset += align;")
                    self.emit_line("    return ptr;")
                    self.emit_line("}")

            if 'malloc' in self.used_externs or 'free' in self.used_externs:
                self.emit_line("#define malloc cbl_malloc")
                self.emit_line("#define free cbl_free")
                if "malloc" not in user_impls or "free" not in user_impls:
                    self.emit_line("typedef struct cbl_free_block { size_t size; struct cbl_free_block* next; } cbl_free_block;")
                    self.emit_line("static cbl_free_block* cbl_free_list = ((void*)0);")
                    self.emit_line("static size_t cbl_heap_offset = 0;")
                if "malloc" not in user_impls:
                    self.emit_line("static inline void* cbl_malloc(size_t size) {")
                    self.emit_line("    if (size == 0) return ((void*)0);")
                    self.emit_line("    size_t align = (size + sizeof(size_t) + 7) & ~7;")
                    self.emit_line("    cbl_free_block** curr = &cbl_free_list;")
                    self.emit_line("    while (*curr) {")
                    self.emit_line("        if ((*curr)->size >= align) {")
                    self.emit_line("            cbl_free_block* block = *curr;")
                    self.emit_line("            *curr = block->next;")
                    self.emit_line("            return (void*)((char*)block + sizeof(size_t));")
                    self.emit_line("        }")
                    self.emit_line("        curr = &(*curr)->next;")
                    self.emit_line("    }")
                    self.emit_line("    if (cbl_heap_offset == 0) cbl_heap_offset = __builtin_wasm_memory_size(0) * 65536;")
                    self.emit_line("    if (cbl_heap_offset + align > __builtin_wasm_memory_size(0) * 65536) {")
                    self.emit_line("        __builtin_wasm_memory_grow(0, ((cbl_heap_offset + align - __builtin_wasm_memory_size(0) * 65536) + 65535) / 65536);")
                    self.emit_line("    }")
                    self.emit_line("    size_t* ptr = (size_t*)((char*)0 + cbl_heap_offset);")
                    self.emit_line("    *ptr = align;")
                    self.emit_line("    cbl_heap_offset += align;")
                    self.emit_line("    return (void*)(ptr + 1);")
                    self.emit_line("}")
                if "free" not in user_impls:
                    self.emit_line("static inline void cbl_free(void* ptr) {")
                    self.emit_line("    if (!ptr) return;")
                    self.emit_line("    cbl_free_block* block = (cbl_free_block*)((char*)ptr - sizeof(size_t));")
                    self.emit_line("    block->next = cbl_free_list;")
                    self.emit_line("    cbl_free_list = block;")
                    self.emit_line("}")
            
            if 'Cblerr_print_string' in self.used_externs or 'Cblerr_print_fast' in self.used_externs:
                if "wasm_print" not in all_user_funcs:
                    self.emit_line('__attribute__((import_module("env"), import_name("print"))) extern void wasm_print(const char* ptr, int32_t len);')
                    
            if 'Cblerr_print_string' in self.used_externs and "Cblerr_print_string" not in user_impls:
                self.emit_line("static inline void Cblerr_print_string(string s) {")
                self.emit_line("    wasm_print(s.data, (int32_t)s.length);")
                self.emit_line("}")
                
            if 'Cblerr_print_fast' in self.used_externs and "Cblerr_print_fast" not in user_impls:
                self.emit_line("static inline void Cblerr_print_fast(string s) {")
                self.emit_line("    wasm_print(s.data, (int32_t)s.length);")
                self.emit_line("}")

        math_externs = {'sin', 'cos', 'tan', 'pow', 'sqrt', 'asin', 'acos', 'atan', 'atan2', 'log', 'exp', 'floor', 'ceil', 'fmod', 'abs', 'fabs'}
        used_math = [name for name in math_externs if name in self.used_externs]
        
        if 'acos' in used_math and 'asin' not in used_math:
            used_math.append('asin')
        
        for f in used_math:
            self.emit_line(f"#define {f} cbl_{f}")

        if used_math:
            if 'fabs' in used_math and "fabs" not in user_impls:
                self.emit_line("static inline double cbl_fabs(double x) { return x < 0.0 ? -x : x; }")
            if 'abs' in used_math and "abs" not in user_impls:
                self.emit_line("static inline int cbl_abs(int x) { return x < 0 ? -x : x; }")
            if 'sqrt' in used_math and "sqrt" not in user_impls:
                self.emit_line("static inline double cbl_sqrt(double x) { return __builtin_sqrt(x); }")
            if 'floor' in used_math and "floor" not in user_impls:
                self.emit_line("static inline double cbl_floor(double x) { return __builtin_floor(x); }")
            if 'ceil' in used_math and "ceil" not in user_impls:
                self.emit_line("static inline double cbl_ceil(double x) { return __builtin_ceil(x); }")
            if 'fmod' in used_math and "fmod" not in user_impls:
                self.emit_line("static inline double cbl_fmod(double x, double y) { return __builtin_fmod(x, y); }")
            if 'exp' in used_math and "exp" not in user_impls:
                self.emit_line("static inline double cbl_exp(double x) { return __builtin_exp(x); }")
            if 'pow' in used_math and "pow" not in user_impls:
                self.emit_line("static inline double cbl_pow(double x, double y) { return __builtin_pow(x, y); }")

            if 'sin' in used_math and "sin" not in user_impls:
                self.emit_line("static inline double cbl_sin(double x) {")
                self.emit_line("    double rx = __builtin_fmod(x, 6.283185307179586);")
                self.emit_line("    if (rx > 3.141592653589793) rx -= 6.283185307179586;")
                self.emit_line("    else if (rx < -3.141592653589793) rx += 6.283185307179586;")
                self.emit_line("    double x2 = rx * rx;")
                self.emit_line("    return rx * (1.0 + x2 * (-0.16666666666666666 + x2 * (0.008333333333333333 + x2 * (-0.0001984126984126984 + x2 * (0.000002755731922398589 + x2 * (-0.00000002505210838544172 + x2 * 0.0000000001605904383682161))))));")
                self.emit_line("}")
                
            if 'cos' in used_math and "cos" not in user_impls:
                self.emit_line("static inline double cbl_cos(double x) {")
                self.emit_line("    double rx = __builtin_fmod(x, 6.283185307179586);")
                self.emit_line("    if (rx > 3.141592653589793) rx -= 6.283185307179586;")
                self.emit_line("    else if (rx < -3.141592653589793) rx += 6.283185307179586;")
                self.emit_line("    double x2 = rx * rx;")
                self.emit_line("    return 1.0 + x2 * (-0.5 + x2 * (0.041666666666666664 + x2 * (-0.001388888888888889 + x2 * (0.0000248015873015873 + x2 * (-0.0000002755731922398589 + x2 * (0.0000000020876756987868 - x2 * 0.0000000000114707455977))))));")
                self.emit_line("}")
                
            if 'tan' in used_math and "tan" not in user_impls:
                self.emit_line("static inline double cbl_tan(double x) {")
                self.emit_line("    double rx = __builtin_fmod(x, 3.141592653589793);")
                self.emit_line("    if (rx > 1.5707963267948966) rx -= 3.141592653589793;")
                self.emit_line("    else if (rx < -1.5707963267948966) rx += 3.141592653589793;")
                self.emit_line("    double x2 = rx * rx;")
                self.emit_line("    double num = rx * (1.0 + x2 * (-0.11528658694082823 + x2 * 0.002241676648721473));")
                self.emit_line("    double den = 1.0 + x2 * (-0.4486199202741615 + x2 * (0.03964952093557997 - x2 * 0.0006275819717141527));")
                self.emit_line("    return num / den;")
                self.emit_line("}")

            if 'atan' in used_math and "atan" not in user_impls:
                self.emit_line("static inline double cbl_atan(double x) {")
                self.emit_line("    double a = (x < 0.0 ? -x : x);")
                self.emit_line("    int invert = a > 1.0;")
                self.emit_line("    if (invert) a = 1.0 / a;")
                self.emit_line("    double z2 = a * a;")
                self.emit_line("    double p;")
                self.emit_line("    if (a > 0.41421356237309503) {")
                self.emit_line("        double num = (a - 1.0) / (a + 1.0);")
                self.emit_line("        double num2 = num * num;")
                self.emit_line("        p = 0.7853981633974483 + num * (1.0 + num2 * (-0.3333333333333333 + num2 * (0.2 + num2 * (-0.14285714285714285 + num2 * (0.1111111111111111 + num2 * (-0.09090909090909091 + num2 * 0.07692307692307693))))));")
                self.emit_line("    } else {")
                self.emit_line("        p = a * (1.0 + z2 * (-0.3333333333333333 + z2 * (0.2 + z2 * (-0.14285714285714285 + z2 * (0.1111111111111111 + z2 * (-0.09090909090909091 + z2 * 0.07692307692307693))))));")
                self.emit_line("    }")
                self.emit_line("    if (invert) p = 1.5707963267948966 - p;")
                self.emit_line("    return x < 0.0 ? -p : p;")
                self.emit_line("}")

            if 'atan2' in used_math and "atan2" not in user_impls:
                self.emit_line("static inline double cbl_atan2(double y, double x) {")
                self.emit_line("    if (y == 0.0 && x == 0.0) return 0.0;")
                self.emit_line("    double abs_y = (y < 0.0 ? -y : y);")
                self.emit_line("    double abs_x = (x < 0.0 ? -x : x);")
                self.emit_line("    int invert = abs_y > abs_x;")
                self.emit_line("    double a = invert ? (abs_x / abs_y) : (abs_y / abs_x);")
                self.emit_line("    double z2 = a * a;")
                self.emit_line("    double p;")
                self.emit_line("    if (a > 0.41421356237309503) {")
                self.emit_line("        double num = (a - 1.0) / (a + 1.0);")
                self.emit_line("        double num2 = num * num;")
                self.emit_line("        p = 0.7853981633974483 + num * (1.0 + num2 * (-0.3333333333333333 + num2 * (0.2 + num2 * (-0.14285714285714285 + num2 * (0.1111111111111111 + num2 * (-0.09090909090909091 + num2 * 0.07692307692307693))))));")
                self.emit_line("    } else {")
                self.emit_line("        p = a * (1.0 + z2 * (-0.3333333333333333 + z2 * (0.2 + z2 * (-0.14285714285714285 + z2 * (0.1111111111111111 + z2 * (-0.09090909090909091 + z2 * 0.07692307692307693))))));")
                self.emit_line("    }")
                self.emit_line("    if (invert) p = 1.5707963267948966 - p;")
                self.emit_line("    if (x < 0.0) p = 3.141592653589793 - p;")
                self.emit_line("    return y < 0.0 ? -p : p;")
                self.emit_line("}")

            if 'asin' in used_math and "asin" not in user_impls:
                self.emit_line("static inline double cbl_asin(double x) {")
                self.emit_line("    double a = (x < 0.0 ? -x : x);")
                self.emit_line("    if (a > 1.0) return 0.0 / 0.0;")
                self.emit_line("    double poly = 1.5707963267948966 + a * (-0.2145988016 + a * (0.0889789874 + a * (-0.0501743046 + a * (0.0308918810 + a * (-0.0170881256 + a * (0.0066700901 - a * 0.0012624911))))));")
                self.emit_line("    double res = 1.5707963267948966 - __builtin_sqrt(1.0 - a) * poly;")
                self.emit_line("    double m2 = (x < 0.0);")
                self.emit_line("    return res * (1.0 - 2.0 * m2);")
                self.emit_line("}")

            if 'acos' in used_math and "acos" not in user_impls:
                self.emit_line("static inline double cbl_acos(double x) { return 1.5707963267948966 - cbl_asin(x); }")

            if 'log' in used_math and "log" not in user_impls:
                self.emit_line("static inline double cbl_log(double x) {")
                self.emit_line("    if (x < 0.0) return 0.0 / 0.0;")
                self.emit_line("    if (x == 0.0) return -1.0 / 0.0;")
                self.emit_line("    double term = (x - 1.0) / (x + 1.0);")
                self.emit_line("    double t2 = term * term;")
                self.emit_line("    double poly = 0.07692307692307693;")
                self.emit_line("    poly = 0.09090909090909091 + t2 * poly;")
                self.emit_line("    poly = 0.11111111111111110 + t2 * poly;")
                self.emit_line("    poly = 0.14285714285714285 + t2 * poly;")
                self.emit_line("    poly = 0.20000000000000000 + t2 * poly;")
                self.emit_line("    poly = 0.33333333333333330 + t2 * poly;")
                self.emit_line("    poly = 1.00000000000000000 + t2 * poly;")
                self.emit_line("    return 2.0 * term * poly;")
                self.emit_line("}")
            self.emit_line()

        mem_funcs = {'memset', 'memcpy', 'memmove', 'memcmp', 'strcmp', 'strlen'}
        used_mem = [name for name in mem_funcs if name in self.used_externs]
        
        for implicit in ('memcpy', 'memset', 'memcmp'):
            if implicit not in used_mem:
                used_mem.append(implicit)

        for f in used_mem:
            self.emit_line(f"#define {f} cbl_{f}")

        if used_mem:
            if 'memset' in used_mem and 'memset' not in user_impls:
                self.emit_line("static inline void* cbl_memset(void *dest, int val, size_t count) {")
                self.emit_line("    char *d = (char*)dest;")
                self.emit_line("    uint64_t v = (unsigned char)val;")
                self.emit_line("    v |= v << 8; v |= v << 16; v |= v << 32;")
                self.emit_line("    while (count >= 8) { *(uint64_t*)d = v; d += 8; count -= 8; }")
                self.emit_line("    while (count--) *d++ = (char)val;")
                self.emit_line("    return dest;")
                self.emit_line("}")
            
            if 'memcpy' in used_mem and 'memcpy' not in user_impls:
                self.emit_line("static inline void* cbl_memcpy(void *dest, const void *src, size_t count) {")
                self.emit_line("    char *d = (char*)dest; const char *s = (const char*)src;")
                self.emit_line("    while (count >= 8) { *(uint64_t*)d = *(const uint64_t*)s; d += 8; s += 8; count -= 8; }")
                self.emit_line("    while (count--) *d++ = *s++;")
                self.emit_line("    return dest;")
                self.emit_line("}")

            if 'memcmp' in used_mem and 'memcmp' not in user_impls:
                self.emit_line("static inline int cbl_memcmp(const void *s1, const void *s2, size_t count) {")
                self.emit_line("    const char *p1 = (const char*)s1, *p2 = (const char*)s2;")
                self.emit_line("    while (count >= 8) {")
                self.emit_line("        if (*(const uint64_t*)p1 != *(const uint64_t*)p2) break;")
                self.emit_line("        p1 += 8; p2 += 8; count -= 8;")
                self.emit_line("    }")
                self.emit_line("    while (count--) {")
                self.emit_line("        if (*p1 != *p2) return (unsigned char)*p1 - (unsigned char)*p2;")
                self.emit_line("        p1++; p2++;")
                self.emit_line("    }")
                self.emit_line("    return 0;")
                self.emit_line("}")

            if 'memmove' in used_mem and 'memmove' not in user_impls:
                self.emit_line("static inline void* cbl_memmove(void *dest, const void *src, size_t count) {")
                self.emit_line("    char *d = (char*)dest; const char *s = (const char*)src;")
                self.emit_line("    if (d < s) { while (count--) *d++ = *s++; }")
                self.emit_line("    else { d += count; s += count; while (count--) *--d = *--s; }")
                self.emit_line("    return dest;")
                self.emit_line("}")

            if 'strcmp' in used_mem and 'strcmp' not in user_impls:
                self.emit_line("static inline int cbl_strcmp(const char *s1, const char *s2) {")
                self.emit_line("    while (*s1 && (*s1 == *s2)) { s1++; s2++; }")
                self.emit_line("    return *(const unsigned char*)s1 - *(const unsigned char*)s2;")
                self.emit_line("}")

            if 'strlen' in used_mem and 'strlen' not in user_impls:
                self.emit_line("static inline size_t cbl_strlen(const char *s) {")
                self.emit_line("    size_t len = 0;")
                self.emit_line("    while (s[len]) len++;")
                self.emit_line("    return len;")
                self.emit_line("}")
            self.emit_line()

        if 'memcmp' in self.used_externs or 'strcmp' in self.used_externs or 'flux_string_eq' in self.used_externs:
            if "flux_string_eq" not in user_impls:
                self.emit_line("static inline bool flux_string_eq(string a, string b) {")
                self.emit_line("    if (a.length != b.length) return false;")
                self.emit_line("    if (!a.length) return true;")
                self.emit_line("    if (!a.data || !b.data) return false;")
                self.emit_line("    return cbl_memcmp(a.data, b.data, a.length) == 0;")
                self.emit_line("}") 
        self.emit_line()

    def _emit_entry_point(self):
        has_globals = len(self.dynamic_globals) > 0
        
        if has_globals:
            if self.target == "linux" and self.link_mode != 'static':
                self.emit_line("void __attribute__((constructor)) CblerrInitGlobals(void) {")
            else:
                self.emit_line("void CblerrInitGlobals(void) {")
                
            for name, val_code in self.dynamic_globals:
                self.emit_line(f"    {name} = {val_code};")
            self.emit_line("}")
            self.emit_line()

        main_func = next((f for f in self.program.functions if f.name == 'main'), None)
        main_returns_void = main_func and (main_func.return_type == 'void' or main_func.return_type is None)

        if self.target == "windows":
            if self.is_dll:
                self.emit_line("int __stdcall DllMainCRTStartup(void* hinstDLL, unsigned int fdwReason, void* lpvReserved) {")
                self.emit_line("    if (fdwReason == 1) { ")
                self.emit_line("        CblerrInitMsvcrt();")
                if has_globals: self.emit_line("        CblerrInitGlobals();")
                self.emit_line("    }")
                self.emit_line("    return 1; // TRUE")
                self.emit_line("}")
            else:
                self.emit_line("void __stdcall WinMainCRTStartup(void) {")
                if not self.is_gui_app and getattr(self, 'needs_utf8', False):
                    self.emit_line("    SetConsoleOutputCP(65001);")
                self.emit_line("    CblerrInitMsvcrt();")
                if has_globals: self.emit_line("    CblerrInitGlobals();")
                if main_returns_void:
                    self.emit_line("    main();")
                    self.emit_line("    ExitProcess(0);")
                else:
                    self.emit_line("    int ret = main();")
                    self.emit_line("    ExitProcess(ret);")
                self.emit_line("}")
                self.emit_line("void __stdcall mainCRTStartup(void) { WinMainCRTStartup(); }")
            
        elif self.target == "linux":
            self.emit_line("void __attribute__((naked)) _start(void) {")
            self.emit_line("    __asm__ volatile (")
            if has_globals:
                self.emit_line('        "call CblerrInitGlobals\\n"')
            self.emit_line('        "call main\\n"')
            self.emit_line('        "mov %rax, %rdi\\n"')
            self.emit_line('        "mov $60, %rax\\n"')
            self.emit_line('        "syscall\\n"')
            self.emit_line("    );")
            self.emit_line("}")

        elif self.target == "wasm":
            self.emit_line("__attribute__((export_name(\"_start\")))")
            self.emit_line("int _start(void) {")
            if has_globals: self.emit_line("    CblerrInitGlobals();")
            if main_returns_void:
                self.emit_line("    main();")
                self.emit_line("    return 0;")
            else:
                self.emit_line("    return main();")
            self.emit_line("}")

    def _get_c_type(self, flux_type) -> str:
        if flux_type is None or flux_type == 'void': return "void"
        type_map = {
            'int': 'int32_t', 'i32': 'int32_t', 'int32': 'int32_t',
            'int64': 'int64_t', 'i64': 'int64_t', 'i16': 'int16_t',
            'i8': 'int8_t', 'u8': 'uint8_t', 'u16': 'uint16_t',
            'u32': 'uint32_t', 'u64': 'uint64_t', 'float': 'float',
            'f32': 'float', 'f64': 'double', 'bool': 'bool', 'str': 'string',
            'char': 'char'
        }
        if hasattr(flux_type, 'name') and hasattr(flux_type, 'args'):
            if flux_type.name == 'array': return f"{self._get_c_type(flux_type.args[0] if flux_type.args else 'int')}*"
            if flux_type.args: return self._get_c_type(flux_type.args[0])
            return "int32_t"
        
        if flux_type in type_map: return type_map[flux_type]
        if isinstance(flux_type, str) and flux_type.startswith('*'): return f"{self._get_c_type(flux_type[1:])}*"
        if isinstance(flux_type, str) and flux_type.startswith('ptr<'): return f"{self._get_c_type(flux_type[4:-1])}*"
        if isinstance(flux_type, str) and flux_type not in type_map: return f"struct {flux_type}"
        return "int32_t"

    def _get_c_declaration(self, flux_type, name: str) -> str:
        if not isinstance(flux_type, str) or not flux_type.startswith('*fn('): 
            return f"{self._get_c_type(flux_type)} {name}"
            
        depth = 0
        start = flux_type.find('(')
        pos = start + 1
        while pos < len(flux_type):
            if flux_type[pos] == '(': depth += 1
            elif flux_type[pos] == ')':
                if depth == 0: break
                depth -= 1
            pos += 1
            
        params_sec = flux_type[start+1:pos].strip()
        rest = flux_type[pos+1:].strip()
        ret = rest[2:].strip() if rest.startswith('->') else 'void'
        
        params = []
        if params_sec:
            current = []
            p_depth = 0
            for char in params_sec:
                if char == '(': p_depth += 1
                elif char == ')': p_depth -= 1
                elif char == ',' and p_depth == 0:
                    params.append(''.join(current).strip())
                    current = []
                    continue
                current.append(char)
            if current:
                params.append(''.join(current).strip())
                
        param_cs = [self._get_c_type(p) for p in params] if params else ['void']
        return f"{self._get_c_type(ret)} (*{name})({', '.join(param_cs)})"

    def _generate_struct_def(self, struct_def: StructDef):
        self.emit_line(f"struct {struct_def.name} {{")
        self.indent_level += 1
        fields_items = struct_def.fields.items() if isinstance(struct_def.fields, dict) else struct_def.fields
        for item in fields_items:
            if isinstance(item, tuple):
                field_name, field_type = item
                if isinstance(field_type, str) and field_type.startswith('*fn('):
                    self.emit_line(f"{self._get_c_declaration(field_type, field_name)};")
                else:
                    self.emit_line(f"{self._get_c_type(field_type)} {field_name};")
        self.indent_level -= 1
        self.emit_line("};")

    def _generate_enum(self, enum_def: EnumDef):
        self.emit_line(f"typedef enum {{")
        self.indent_level += 1
        for name, val in enum_def.members:
            if val is not None: self.emit_line(f"{name} = {self._generate_expression(val)},")
            else: self.emit_line(f"{name},")
        self.indent_level -= 1
        self.emit_line(f"}} {enum_def.name};")

    def _generate_global_var(self, global_var):
        if isinstance(global_var.var_type, str) and global_var.var_type.startswith('*fn('):
            decl = self._get_c_declaration(global_var.var_type, global_var.name)
            self.global_vars[global_var.name] = global_var
            if getattr(global_var, 'value', None):
                value_code = self._generate_expression(global_var.value)
                if isinstance(global_var.value, (Literal, Variable)): self.emit_line(f"{decl} = {value_code};")
                else: 
                    self.emit_line(f"{decl};")
                    self.dynamic_globals.append((global_var.name, value_code))
            else: self.emit_line(f"{decl};")
            return
            
        c_type = self._get_c_type(global_var.var_type)
        if hasattr(global_var, 'var_type') and getattr(global_var.var_type, 'name', None) == 'array':
            inner = global_var.var_type.args[0] if getattr(global_var.var_type, 'args', None) else 'int'
            c_type = f"{self._get_c_type(inner)}[]"
            
        self.global_vars[global_var.name] = global_var
        
        if getattr(global_var, 'value', None):
            value_code = self._generate_expression(global_var.value)
            if isinstance(global_var.value, (Literal, ArrayLiteral, Variable)):
                if c_type.endswith('[]'): self.emit_line(f"{c_type[:-2]} {global_var.name}[] = {value_code};")
                else: self.emit_line(f"{c_type} {global_var.name} = {value_code};")
            else:
                if c_type.endswith('[]'): self.emit_line(f"{c_type[:-2]} {global_var.name}[];")
                else: self.emit_line(f"{c_type} {global_var.name};")
                self.dynamic_globals.append((global_var.name, value_code))
        else:
            if c_type.endswith('[]'): self.emit_line(f"{c_type[:-2]} {global_var.name}[];")
            else: self.emit_line(f"{c_type} {global_var.name};")

    def _generate_function_signature(self, func_def: FunctionDef) -> str:
        return_type = self._get_c_type(func_def.return_type)
        params = []
        if func_def.params:
            for param_tuple in func_def.params:
                if isinstance(param_tuple, tuple) and len(param_tuple) >= 2:
                    pname, ptype = param_tuple[0], param_tuple[1]
                    if isinstance(ptype, str) and ptype.startswith('*fn('):
                        params.append(self._get_c_declaration(ptype, pname))
                    else:
                        params.append(f"{self._get_c_type(ptype)} {pname}")
        params_str = ", ".join(params) if params else "void"
        
        if getattr(func_def, 'is_vararg', False):
            if params_str == "void": params_str = "..."
            else: params_str += ", ..."
        
        call_conv = " __stdcall" if getattr(func_def, 'is_extern', False) and self.target == 'windows' and (func_def.name.endswith('A') or func_def.name.endswith('W') or func_def.name in self.win_critical_externs) else ""
        return f"{return_type}{call_conv} {func_def.name}({params_str})"

    def _emit_unwind_defers(self, target_depth: int):
        for scope in reversed(self.defer_scopes[target_depth:]):
            for d in reversed(scope):
                self.emit_line("{")
                self.indent_level += 1
                for s in d.body:
                    self._generate_statement(s)
                self.indent_level -= 1
                self.emit_line("}")

    def _generate_function_def(self, func_def: FunctionDef):
        sig = self._generate_function_signature(func_def)
        self.emit_line(f"{sig} {{")
        self.indent_level += 1
        self.current_function = func_def.name
        self.local_vars_stack.append({})
        self.defer_scopes.append([])

        if func_def.params:
            for param_tuple in func_def.params:
                if isinstance(param_tuple, tuple) and len(param_tuple) >= 2:
                    pname, ptype = param_tuple[0], param_tuple[1]
                    try:
                        p_c = self._get_c_declaration(ptype, pname) if isinstance(ptype, str) and ptype.startswith('*fn(') else self._get_c_type(ptype)
                        if p_c: self.local_vars_stack[-1][pname] = p_c
                    except: pass

        has_explicit_return = bool(func_def.body and func_def.body[-1].__class__.__name__ == 'Return')
        if func_def.body:
            for stmt in func_def.body:
                self._generate_statement(stmt)

        if not has_explicit_return:
            self._emit_unwind_defers(len(self.defer_scopes) - 1)
            if func_def.return_type != 'void' and func_def.return_type is not None:
                if func_def.return_type in ['int', 'i32', 'int32']: self.emit_line("return 0;")
                else: self.emit_line(f"return ({self._get_c_type(func_def.return_type)})0;")
        
        self.defer_scopes.pop()
        self.indent_level -= 1
        self.emit_line("}")
        if self.local_vars_stack: self.local_vars_stack.pop()

    def _generate_statement(self, stmt):
        if hasattr(stmt, 'line') and getattr(stmt, 'line', 0) > 0:
            escaped_filename = self._escape_string(self.source_filename)
            self.emit_line(f'#line {stmt.line} "{escaped_filename}"')

        cname = stmt.__class__.__name__

        if cname == 'Return': 
            self._emit_unwind_defers(0)
            if stmt.value: self.emit_line(f"return {self._generate_expression(stmt.value)};")
            else: self.emit_line("return;")
        elif cname == 'Assign':
            target_str = self._generate_expression(stmt.target) if not isinstance(stmt.target, str) else stmt.target
            value_str = self._generate_expression(stmt.value)
            
            var_name = stmt.target if isinstance(stmt.target, str) else getattr(stmt.target, 'name', None)
            
            if getattr(stmt, 'var_type', None):
                c_type = self._get_c_type(stmt.var_type)
                self.emit_line(f"{c_type} {target_str} = {value_str};")
                if self.local_vars_stack and var_name: 
                    self.local_vars_stack[-1][var_name] = c_type
            else:
                self.emit_line(f"{target_str} = {value_str};")
        elif cname == 'IfStmt':
            condition = self._generate_expression(stmt.condition)
            self.emit_line(f"if ({condition}) {{")
            self.indent_level += 1
            self.defer_scopes.append([])
            for s in stmt.then_body: self._generate_statement(s)
            if not (stmt.then_body and stmt.then_body[-1].__class__.__name__ in ('Return', 'BreakStmt', 'ContinueStmt')):
                self._emit_unwind_defers(len(self.defer_scopes) - 1)
            self.defer_scopes.pop()
            self.indent_level -= 1
            
            if stmt.else_body:
                self.emit_line("} else {")
                self.indent_level += 1
                self.defer_scopes.append([])
                for s in stmt.else_body: self._generate_statement(s)
                if not (stmt.else_body and stmt.else_body[-1].__class__.__name__ in ('Return', 'BreakStmt', 'ContinueStmt')):
                    self._emit_unwind_defers(len(self.defer_scopes) - 1)
                self.defer_scopes.pop()
                self.indent_level -= 1
            self.emit_line("}")
        elif cname == 'WhileLoop':
            condition = self._generate_expression(stmt.condition)
            self.emit_line(f"while ({condition}) {{")
            self.indent_level += 1
            self.defer_scopes.append([])
            self.loop_depths.append(len(self.defer_scopes) - 1)
            for s in stmt.body: self._generate_statement(s)
            if not (stmt.body and stmt.body[-1].__class__.__name__ in ('Return', 'BreakStmt', 'ContinueStmt')):
                self._emit_unwind_defers(len(self.defer_scopes) - 1)
            self.loop_depths.pop()
            self.defer_scopes.pop()
            self.indent_level -= 1
            self.emit_line("}")
        elif cname == 'ForLoop':
            if getattr(stmt, 'iter_var', None) is not None:
                iter_var = stmt.iter_var
                range_call = stmt.iter_expr
                start, end = "0", "0"
                
                r_name = None
                if hasattr(range_call, 'func_name'):
                    r_name = range_call.func_name if isinstance(range_call.func_name, str) else getattr(range_call.func_name, 'name', None)
                
                if r_name == 'range' and hasattr(range_call, 'args') and len(range_call.args) == 2:
                    start = self._generate_expression(range_call.args[0])
                    end = self._generate_expression(range_call.args[1])
                
                self.emit_line(f"for (int32_t {iter_var} = {start}; {iter_var} < {end}; {iter_var}++) {{")
                self.local_vars_stack[-1][iter_var] = "int32_t"
                self.indent_level += 1
                self.defer_scopes.append([])
                self.loop_depths.append(len(self.defer_scopes) - 1)
                
                for s in stmt.body: self._generate_statement(s)
                
                if not (stmt.body and stmt.body[-1].__class__.__name__ in ('Return', 'BreakStmt', 'ContinueStmt')):
                    self._emit_unwind_defers(len(self.defer_scopes) - 1)
                
                self.loop_depths.pop()
                self.defer_scopes.pop()
                self.indent_level -= 1
                self.emit_line("}")
            else:
                self.emit_line("{")
                self.indent_level += 1
                init_code = ""
                if getattr(stmt, 'init', None):
                    if stmt.init.__class__.__name__ == 'Assign':
                        tgt = self._generate_expression(stmt.init.target) if not isinstance(stmt.init.target, str) else stmt.init.target
                        val = self._generate_expression(stmt.init.value)
                        if getattr(stmt.init, 'var_type', None):
                            c_t = self._get_c_type(stmt.init.var_type)
                            init_code = f"{c_t} {tgt} = {val}"
                            if stmt.init.target.__class__.__name__ == 'Variable':
                                self.local_vars_stack[-1][stmt.init.target.name] = c_t
                            elif isinstance(stmt.init.target, str):
                                self.local_vars_stack[-1][stmt.init.target] = c_t
                        else:
                            init_code = f"{tgt} = {val}"
                    else:
                        expr_res = self._generate_expression(stmt.init)
                        init_code = "" if expr_res == "0" else expr_res
                
                cond_code = self._generate_expression(stmt.condition) if getattr(stmt, 'condition', None) else "1"
                
                post_code = ""
                if getattr(stmt, 'post', None):
                    if stmt.post.__class__.__name__ == 'Assign':
                        tgt = self._generate_expression(stmt.post.target) if not isinstance(stmt.post.target, str) else stmt.post.target
                        val = self._generate_expression(stmt.post.value)
                        post_code = f"{tgt} = {val}"
                    else:
                        expr_res = self._generate_expression(stmt.post)
                        post_code = "" if expr_res == "0" else expr_res

                self.emit_line(f"for ({init_code}; {cond_code}; {post_code}) {{")
                self.indent_level += 1
                self.defer_scopes.append([])
                self.loop_depths.append(len(self.defer_scopes) - 1)
                
                for s in stmt.body: self._generate_statement(s)
                
                if not (stmt.body and stmt.body[-1].__class__.__name__ in ('Return', 'BreakStmt', 'ContinueStmt')):
                    self._emit_unwind_defers(len(self.defer_scopes) - 1)
                
                self.loop_depths.pop()
                self.defer_scopes.pop()
                self.indent_level -= 1
                self.emit_line("}")
                self.indent_level -= 1
                self.emit_line("}")
        elif cname == 'MatchStmt':
            expr_code = self._generate_expression(stmt.expr)
            temp_var = f"__match_val_{len(self.local_vars_stack)}_{id(stmt)}"
            
            expr_type = getattr(stmt.expr, 'resolved_type', getattr(stmt.expr, 'type', None))
            c_expr_type = self._get_c_type(expr_type) if expr_type else "int64_t" 
            
            self.emit_line(f"{c_expr_type} {temp_var} = {expr_code};")
            
            is_first = True
            for case in stmt.cases:
                if case.values:
                    conds = []
                    for val in case.values:
                        val_code = self._generate_expression(val)
                        if '"' in val_code or '.length' in val_code:
                            conds.append(f"flux_string_eq({temp_var}, {val_code})")
                        else:
                            conds.append(f"({temp_var} == {val_code})")
                    cond_str = " || ".join(conds)
                    
                    if is_first:
                        self.emit_line(f"if ({cond_str}) {{")
                        is_first = False
                    else:
                        self.emit_line(f"}} else if ({cond_str}) {{")
                else:
                    if is_first:
                        self.emit_line(f"if (1) {{")
                        is_first = False
                    else:
                        self.emit_line(f"}} else {{")
                        
                self.indent_level += 1
                self.defer_scopes.append([])
                for s in case.body: self._generate_statement(s)
                if not (case.body and case.body[-1].__class__.__name__ in ('Return', 'BreakStmt', 'ContinueStmt')):
                    self._emit_unwind_defers(len(self.defer_scopes) - 1)
                self.defer_scopes.pop()
                self.indent_level -= 1
            if not is_first:
                self.emit_line("}")
        elif cname == 'BreakStmt':
            if self.loop_depths:
                self._emit_unwind_defers(self.loop_depths[-1])
            self.emit_line("break;")
        elif cname == 'ContinueStmt':
            if self.loop_depths:
                self._emit_unwind_defers(self.loop_depths[-1])
            self.emit_line("continue;")
        elif cname == 'DeferStmt':
            if self.defer_scopes:
                self.defer_scopes[-1].append(stmt)
        elif cname == 'InlineAsm': self.emit_line(f'__asm__ volatile ("{self._escape_string(stmt.code)}");')
        elif cname == 'Call':
            self.emit_line(f"{self._generate_expression(stmt)};")
        else:
            expr_code = self._generate_expression(stmt)
            if expr_code and expr_code != "0": self.emit_line(f"{expr_code};")

    def _generate_expression(self, expr) -> str:
        if expr is None: return "0"
        
        cname = expr.__class__.__name__

        if cname == 'Literal':
            if isinstance(expr.value, str):
                val = expr.value
                return self.string_pool.get(val, '((string){(char*)"",0})')
            elif isinstance(expr.value, float): return str(expr.value)
            elif isinstance(expr.value, bool): return "true" if expr.value else "false"
            else: return str(expr.value)
        
        elif cname == 'Variable': return expr.name
        elif cname == 'BinaryOp':
            left, right = self._generate_expression(expr.left), self._generate_expression(expr.right)
            if expr.op == '**': return f"pow({left}, {right})"
            op_map = {'+': '+', '-': '-', '*': '*', '/': '/', '%': '%', '&': '&', '|': '|', '^': '^', '<<': '<<', '>>': '>>'}
            return f"({left} {op_map.get(expr.op, expr.op)} {right})"
        
        elif cname == 'Compare':
            left, right = self._generate_expression(expr.left), self._generate_expression(expr.right)
            left_t = getattr(expr.left, 'resolved_type', getattr(expr.left, 'type', None))
            right_t = getattr(expr.right, 'resolved_type', getattr(expr.right, 'type', None))
            
            def is_str(node, t):
                if t == 'str': return True
                if node.__class__.__name__ == 'Variable':
                    c_t = self._get_local_c_type(node.name)
                    if c_t in ('string', 'flux_string'): return True
                return False
                
            if is_str(expr.left, left_t) or is_str(expr.right, right_t):
                if expr.op == '==': return f"flux_string_eq({left}, {right})"
                elif expr.op == '!=': return f"(!flux_string_eq({left}, {right}))"
            return f"({left} {expr.op} {right})"
        
        elif cname == 'LogicalOp':
            if expr.op == 'not': return f"(!{self._generate_expression(expr.left)})"
            return f"({self._generate_expression(expr.left)} {'&&' if expr.op == 'and' else '||'} {self._generate_expression(expr.right)})"
        
        elif cname == 'Call':
            fname = expr.func_name if isinstance(expr.func_name, str) else getattr(expr.func_name, 'name', None)
            if fname == 'print': 
                if getattr(expr, '_is_fast_print', None) is not None:
                    fast_val = expr._is_fast_print
                    pool_name = self.string_pool.get(fast_val, '((string){(char*)"",0})')
                    return f"Cblerr_print_fast({pool_name})"
                
                if not getattr(expr, 'args', None):
                    return "0"
                    
                prints = []
                for arg in expr.args:
                    arg_code = self._generate_expression(arg)
                    prints.append(f"Cblerr_print_string({arg_code})")
                    
                if prints:
                    if len(prints) == 1:
                        return prints[0]
                    return "(" + ", ".join(prints) + ", 0)"
                return "0"
            
            if fname == 'len':
                if not expr.args: return '0'
                a = expr.args[0]
                a_code = self._generate_expression(a)
                a_type = getattr(a, 'resolved_type', getattr(a, 'type', None))
                
                if not a_type and a.__class__.__name__ == 'Variable':
                    c_t = self._get_local_c_type(a.name)
                    if c_t in ('string', 'flux_string'):
                        a_type = 'str'

                if a_type == 'str': return f"({a_code}.length)"
                return f"(sizeof({a_code})/sizeof({a_code}[0]))"

            args_str = ", ".join([self._generate_expression(arg) for arg in (expr.args or [])])
            func_code = fname if fname else self._generate_expression(expr.func_name)
            return f"{func_code}({args_str})"
        
        elif cname == 'ArrayAccess': return f"{self._generate_expression(expr.arr)}[{self._generate_expression(expr.index)}]"
        elif cname == 'FieldAccess':
            obj = self._generate_expression(expr.obj)
            obj_type = getattr(expr.obj, 'resolved_type', None)
            
            if expr.obj.__class__.__name__ == 'Variable' and expr.obj.name in getattr(self, 'imported_modules', set()):
                if not self._get_local_c_type(expr.obj.name):
                    return f"{expr.obj.name}____{expr.field}"
            
            use_arrow = False
            if isinstance(obj_type, str) and (obj_type.startswith('*') or obj_type.startswith('ptr<')):
                use_arrow = True
            elif expr.obj.__class__.__name__ == 'Variable':
                c_t = self._get_local_c_type(expr.obj.name)
                if c_t and '*' in c_t:
                    use_arrow = True
                    
            return f"{obj}->{expr.field}" if use_arrow else f"{obj}.{expr.field}"
        
        elif cname == 'Dereference': return f"(*{self._generate_expression(expr.ptr)})"
        elif cname == 'CastExpr': return f"(({self._get_c_type(expr.target_type)}){self._generate_expression(expr.expr)})"
        elif cname == 'ArrayLiteral':
            elems = [self._generate_expression(e) for e in expr.elements]
            if getattr(expr, 'is_struct_init', False): return "{" + ", ".join(elems) + "}"
            elem_c = self._get_c_type(expr.array_type) if getattr(expr, 'array_type', None) else 'int32_t'
            return f'({elem_c}[]){{' + ", ".join(elems) + '}'
        elif cname == 'AddressOf': return f"&({self._generate_expression(expr.expr)})"
        elif cname == 'SizeOf':
            tgt = expr.target
            if isinstance(tgt, str): return f"sizeof({self._get_c_type(tgt)})"
            elif hasattr(tgt, 'name'): return f"sizeof(struct {tgt.name})"
            else: return f"sizeof({self._generate_expression(tgt)})"
        elif cname == 'WalrusExpr': return f"({self._generate_expression(expr.target)} = {self._generate_expression(expr.value)})"
        return "0"

class StandaloneCompiler:
    def __init__(self, source_file: str, output_exe: str, target: str = "windows", verbose: bool = True,
                 link_mode: Optional[str] = None, stack_reserve: Optional[int] = None,
                 compiler_type: Optional[str] = None, icon_path: Optional[str] = None,
                 extra_files: List[str] = None, m32: bool = False, opt_level: str = '-O3',
                 asm_out: bool = False, profile_time: bool = False,
                 gen_header: bool = False, native_mode: bool = False, v3_mode: bool = False, avx_mode: Optional[str] = None,
                 keep_c: bool = False, derr_flag: bool = False):
        self.source_file = Path(source_file)
        self.output_exe = Path(output_exe)
        self.opt_level = opt_level
        self.asm_out = asm_out
        self.profile_time = profile_time
        self.gen_header = gen_header
        self.native_mode = native_mode
        self.v3_mode = v3_mode
        self.avx_mode = avx_mode
        self.keep_c = keep_c
        self.derr_flag = derr_flag
        
        target_lower = target.lower()
        self.is_dll = (target_lower == 'winlib')
        self.is_scr = (target_lower in ('winsaver', 'screensaver'))
        if target_lower == 'wasm':
            self.target = 'wasm'
        else:
            self.target = 'windows' if (self.is_dll or self.is_scr or target_lower == 'windows') else target_lower
        self.m32 = m32
        
        self.verbose = verbose
        
        self.temp_dir = Path(tempfile.gettempdir()) / "cblerr_standalone"
        self.temp_dir.mkdir(exist_ok=True)
        self.c_file = self.temp_dir / f"{self.source_file.stem}.c"
        
        self.is_windows = (self.target == 'windows')
        if self.target == 'wasm':
            self.obj_file = self.temp_dir / f"{self.source_file.stem}.wasm.o"
        else:
            self.obj_file = self.temp_dir / f"{self.source_file.stem}.obj" if self.is_windows else self.temp_dir / f"{self.source_file.stem}.o"
        
        self.link_mode = link_mode
        self.stack_reserve = stack_reserve
        self.compiler_type = self._select_compiler(compiler_type)
        self.source_code = "" 
        self.icon_path = icon_path
        self.extra_files = extra_files or []
        
        self.is_gui_app = False
        self.packable = False
        self.res_file = None
    
    def log(self, message: str, level: str = "INFO"):
        if not self.verbose and level == "INFO":
            return
            
        message = message.replace("✓", "[OK]").replace("✗", "[FAIL]")
        MAGENTA = "\033[35m"  
        CYAN = "\033[36m"    
        RED = "\033[31m"     
        RESET = "\033[0m"    
        
        message = re.sub(r'\[([\d.]+)/(\d+)\]', f'{CYAN}[\\1/\\2]{RESET}', message)
        message = re.sub(r'\[INFO\]', f'{CYAN}[INFO]{RESET}', message)
        
        if level == "INFO": level_colored = f"{MAGENTA}[{level}]{RESET}"
        elif level == "WARN": level_colored = f"{RED}[{level}]{RESET}"
        else: level_colored = f"{RED}[{level}]{RESET}"
        
        print(f"{level_colored} {message}")

    def _select_compiler(self, forced_compiler: Optional[str]) -> str:
        if forced_compiler:
            c = forced_compiler.lower()
            if c == 'mingw': return 'gcc'
            if c == 'lld': return 'clang'
            return c
        return 'auto'
    
    def _compiler_exists(self, compiler_name: str) -> bool:
        try:
            cmd = f'{compiler_name}.exe' if platform.system() == 'Windows' else compiler_name
            return subprocess.run([cmd, '--version'], capture_output=True, text=True, timeout=5).returncode == 0
        except: return False

    def _print_compiler_installation_guide(self):
        print("\n\033[1;41;37m [CRITICAL ERROR] No C Compiler Found! \033[0m")
        print("\033[0;33mCBlerr compiles your code to C, which requires a C compiler to create the final executable.\033[0m")
        print("\033[1;36mHere is how to install one:\033[0m\n")
        
        if platform.system() == "Windows":
            print("\033[1;32mOption 1: MSYS2 / MinGW-w64 (Recommended, GCC)\033[0m")
            print("  1. Download MSYS2 from \033[4mhttps://www.msys2.org/\033[0m")
            print("  2. Install it and open the 'MSYS2 UCRT64' terminal.")
            print("  3. Run: \033[1;37mpacman -S mingw-w64-ucrt-x86_64-gcc\033[0m")
            print("  4. Add 'C:\\msys64\\ucrt64\\bin' (or mingw64\\bin) to your Windows PATH environment variable.\n")
            
            print("\033[1;32mOption 2: LLVM / Clang\033[0m")
            print("  1. Download the LLVM installer from \033[4mhttps://github.com/llvm/llvm-project/releases\033[0m")
            print("  2. During installation, select 'Add LLVM to the system PATH for all users'.\n")
            
            print("\033[1;32mOption 3: Microsoft Visual Studio (MSVC)\033[0m")
            print("  1. Download Visual Studio Community from \033[4mhttps://visualstudio.microsoft.com/\033[0m")
            print("  2. Install the 'Desktop development with C++' workload.\n")
        elif platform.system() == "Linux":
            print("\033[1;32mUbuntu / Debian:\033[0m")
            print("  Run: \033[1;37msudo apt update && sudo apt install build-essential clang\033[0m\n")
            
            print("\033[1;32mArch Linux:\033[0m")
            print("  Run: \033[1;37msudo pacman -S base-devel clang\033[0m\n")
            
            print("\033[1;32mFedora:\033[0m")
            print("  Run: \033[1;37msudo dnf groupinstall \"C Development Tools and Libraries\" && sudo dnf install clang\033[0m\n")
        else:
            print("\033[1;32mApple macOS:\033[0m")
            print("  1. Open Terminal.")
            print("  2. Run: \033[1;37mxcode-select --install\033[0m")
            print("  3. Follow the prompt to install the command line tools.\n")
            print("\033[1;32mOther OS:\033[0m")
            print("  Please install GCC or Clang using your system's package manager.\n")
        
        print("\033[0;33mAfter installing, restart your terminal and try compiling again!\033[0m\n")

    def _is_msvc_clang(self) -> bool:
        if not hasattr(self, '_cached_is_msvc_clang'):
            try:
                cmd = 'clang.exe' if platform.system() == 'Windows' else 'clang'
                out = subprocess.run([cmd, '-dumpmachine'], capture_output=True, text=True).stdout
                self._cached_is_msvc_clang = 'msvc' in out.lower()
            except:
                self._cached_is_msvc_clang = False
        return self._cached_is_msvc_clang

    def _get_compiler_flags(self, compiler: str = 'gcc') -> str:
        env_cflags = os.getenv('CBLERR_CFLAGS')
        if env_cflags: return env_cflags
        
        flags = (
            f'-std=c11 {self.opt_level} -fno-lto -ffunction-sections -fdata-sections -fno-ident '
            '-fno-asynchronous-unwind-tables -fno-unwind-tables '
            '-fno-exceptions -fno-math-errno '
            '-mno-stack-arg-probe -fno-builtin '
            '-Wno-int-conversion -Wno-incompatible-pointer-types -Wno-implicit-int '
            '-Wno-discarded-qualifiers -Wno-implicit-function-declaration -Wno-pointer-to-int-cast -Wno-int-to-pointer-cast'
        )
        
        is_msvc = (compiler == 'clang' and self._is_msvc_clang() and self.target != 'windows')
        if not is_msvc:
            flags += ' -s -fmerge-all-constants'
            if self.opt_level == '-Os':
                flags += ' -fno-plt'
            if getattr(self, 'native_mode', False) and self.target != 'wasm':
                flags += ' -march=native'
            elif getattr(self, 'v3_mode', False) and self.target != 'wasm':
                flags += ' -march=x86-64-v3'
            
        if self.m32 and self.target != 'wasm':
            flags = '-m32 ' + flags

        if self.target == 'windows': 
            flags += ' -fomit-frame-pointer'
            
        if self.target != 'wasm':
            if getattr(self, 'avx_mode', None) == '512':
                flags += ' -mavx512f -mavx512cd -mavx512bw -mavx512dq -mavx512vl -mstackrealign -mincoming-stack-boundary=3 '
            elif getattr(self, 'avx_mode', None) == '256':
                flags += ' -mavx2'
            elif getattr(self, 'avx_mode', None) == '128':
                flags += ' -mavx'
            else:
                flags += ' -msse2'
            
        return flags
    
    def _get_linker_flags(self, compiler: str = 'gcc') -> str:
        flags = ['-fno-lto']
        is_msvc = (compiler == 'clang' and self._is_msvc_clang() and self.target != 'windows')
        
        if self.m32 and self.target != 'wasm':
            flags.append('-m32')
            
        if self.target == 'windows':
            entry_point = 'DllMainCRTStartup' if self.is_dll else 'WinMainCRTStartup'
            
            if is_msvc:
                flags.extend([
                    '-nostartfiles', '-nostdlib',
                    f'-Wl,-entry:{entry_point}',
                    '-Wl,-nodefaultlib',
                    '-Wl,-align:4096', 
                    '-Wl,-filealign:512'
                ])
                if self.is_dll:
                    flags.extend(['-shared'])
                else:
                    subsys = "windows" if self.is_gui_app else "console"
                    flags.append(f'-Wl,-subsystem:{subsys}')
                
                flags.extend(['-Wl,-opt:ref', '-Wl,-opt:icf'])
            else:
                flags.extend([
                    '-nostartfiles', '-nostdlib', f'-Wl,--entry={entry_point}',
                    '-Wl,--build-id=none', '-Wl,--no-seh'
                ])
                if self.is_dll:
                    flags.extend(['-shared', '-Wl,--export-all-symbols'])
                else:
                    subsys = "windows" if self.is_gui_app else "console"
                    flags.append(f'-Wl,--subsystem,{subsys}')
                
                flags.append('-Wl,--gc-sections')
                
                if compiler in ('gcc', 'clang'):
                    flags.extend(['-Wl,--file-alignment=1', '-Wl,--section-alignment=1'])
                
        elif self.target == 'linux':
            if self.link_mode == 'static' or platform.system() == 'Windows': 
                flags.extend(['-nostdlib', '-static', '-Wl,--build-id=none'])
            else:
                flags.extend(['-lc', '-lm', '-lgcc', '-Wl,--hash-style=sysv'])
            
            if compiler in ('gcc', 'clang', 'lld'):
                flags.append('-Wl,--gc-sections')
        
        if self.stack_reserve and self.target != 'wasm': 
            if is_msvc:
                flags.append(f'-Wl,-stack:{self.stack_reserve}')
            else:
                flags.append(f'-Wl,--stack,{self.stack_reserve}')
                
        return ' '.join(flags)

    def _get_windows_libs(self, compiler: str) -> List[str]:
        libs = ['kernel32', 'user32']
        if compiler == 'gcc':
            libs.append('ntdll')
            
        code = self.source_code.lower()
        if 'opengl' in code or 'wgl' in code or 'glclear' in code or 'glbegin' in code or 'glflush' in code:
            libs.append('opengl32')
        if 'winmm' in code or 'mci' in code or 'playsound' in code or 'timegettime' in code or 'waveout' in code:
            libs.append('winmm')
        if 'gdi32' in code or 'bitblt' in code or 'createcompatible' in code or 'selectobject' in code or 'createdib' in code or 'stretchdibits' in code or 'setdibits' in code or 'deleteobject' in code or 'createfont' in code or 'choosepixelformat' in code or 'swapbuffers' in code:
            libs.append('gdi32')
        if 'advapi32' in code or 'regopen' in code or 'regcreate' in code or 'regset' in code or 'crypt' in code:
            libs.append('advapi32')
        if 'shell32' in code or 'shellexecute' in code or 'dragaccept' in code or 'shget' in code:
            libs.append('shell32')
        if 'ole32' in code or 'coinitialize' in code or 'cocreate' in code:
            libs.append('ole32')
            
        if compiler == 'msvc' or (compiler == 'clang' and self._is_msvc_clang() and self.target != 'windows'):
            return [lib + '.lib' for lib in libs]
        else:
            return ['-l' + lib for lib in libs]

    def _compile_resources(self) -> Optional[str]:
        if not self.is_windows or not self.icon_path:
            return None
        icon_p = Path(self.icon_path).absolute()
        if not icon_p.exists():
            self.log(f"Icon not found: {icon_p}", "WARN")
            return None
        
        icon_path_for_rc = str(icon_p).replace("\\", "\\\\")
        rc_content = '1 ICON "{}"'.format(icon_path_for_rc)
        
        rc_file = self.temp_dir / "resources.rc"
        rc_file.write_text(rc_content)
        out_res = self.temp_dir / "resources.o"
        try:
            cmd = ['windres', str(rc_file), '-o', str(out_res)]
            if self.m32:
                cmd.extend(['-F', 'pe-i386'])
            else:
                cmd.extend(['-F', 'pe-x86-64'])
                
            if subprocess.run(cmd, capture_output=True).returncode == 0:
                return str(out_res)
        except: pass
        return None

    def _prepare_output_file(self):
        for p in (self.output_exe, self.output_exe.with_suffix('.exe'), self.output_exe.with_suffix('.scr')):
            try:
                if p.exists():
                    p.unlink()
            except Exception:
                pass
                
    def compile(self) -> bool:
        t_start = time.perf_counter()
        perf_times = {}
        
        debugger = init_debugger(DebugLevel.INFO)
        self.debugger = debugger
        try:
            target_str = f"{self.target.upper()} (DLL: {self.is_dll}, SCR: {self.is_scr}, 32-bit: {self.m32})"
            self.log(f"CBlerr Console Compiler (CCC)\nTarget OS: {target_str}\nOutput: {self.output_exe}")
            
            self.log("\n[1/9] Reading code...")
            if not self.source_file.exists():
                self.log(f"Uh oh, couldn't find the file: {self.source_file}", "ERROR")
                return False
            self.source_code = open(self.source_file, 'r', encoding='utf-8').read()
            
            if not self.is_gui_app:
                self.is_gui_app = is_gui_app_code(self.source_code)
            self.packable = is_packable_code(self.source_code)
            
            if self.is_gui_app and self.target == 'windows' and not self.is_dll and not self.is_scr:
                self.packable = False
                self.log("  [+] Looks like a GUI application! (Packing disabled)")
            elif self.is_dll:
                self.packable = False
                self.log("  [+] Compiling as a DLL. (Packing disabled to keep it safe!)")
            elif self.is_scr:
                self.is_gui_app = True
                self.packable = False
                self.log("  [+] Compiling as a Windows Screensaver (.scr).")
            elif self.target == 'wasm':
                self.packable = False
                self.log("  [+] Targeting WebAssembly. (No PE packers needed)")
            elif self.packable:
                if self.target == 'windows' and not self.m32:
                    self.packable = False
                    self.log("  [+] 64-bit Windows app detected. (Extreme packing disabled for safety)")
                else:
                    self.log("  [+] Looks like a standard packable app! (Packing enabled)")
                    
            if getattr(self, 'native_mode', False):
                self.log("  [+] Native mode enabled! Optimizing directly for your CPU (-march=native).")
            elif getattr(self, 'v3_mode', False):
                self.log("  [+] x86-64-v3 enabled! Targeting modern CPUs (2015+) with AVX2 and BMI2 instructions.")
                
            if self.avx_mode == '512':
                self.log("  [+] AVX-512 enabled! Maximum vectorization width unlocked (make sure your CPU supports it, e.g., Zen 4+ or Skylake-X).")
            elif self.avx_mode == '256':
                self.log("  [+] AVX256 (AVX2) enabled! Your code will fly, but be aware: some CPUs aggressively drop clock speeds to handle 256-bit math without melting down.")
            elif self.avx_mode == '128':
                self.log("  [+] AVX128 (AVX) enabled. Solid vectorization with much less risk of CPU throttling.")
                    
            t_read = time.perf_counter()
            perf_times['Read Source'] = t_read - t_start

            self.log("\n[2/9] Tokenizing...")
            tokens = tokenize(self.source_code, str(self.source_file))

            t_tok = time.perf_counter()
            perf_times['Lexer'] = t_tok - t_read

            self.log("\n[3/9] Parsing code...")
            ast = parse(tokens)

            try:
                from core.module_loader import inline_imports
                ast = inline_imports(ast, self.source_file)
            except Exception as e:
                self.log(f'Import error: {e}', "ERROR")
                return False

            t_parse = time.perf_counter()
            perf_times['Parser & Imports'] = t_parse - t_tok

            self.log("\n[4/9] Monomorphization...")
            try:
                from core.monomorphizer import monomorphize
                ast = monomorphize(ast)
            except Exception as e:
                self.log(f'Monomorphization error: {e}', "ERROR")
                return False

            t_mono = time.perf_counter()
            perf_times['Monomorphization'] = t_mono - t_parse

            self.log("\n[5/9] AST Optimization (Const Fold & DCE)...")
            ast = fold_constants(ast, debugger)
            ast = run_dce(ast, is_lib=(self.is_dll or self.target == 'wasm'))

            t_opt = time.perf_counter()
            perf_times['Optimizer'] = t_opt - t_mono

            self.log("\n[6/9] Type Checking & Dead Variables Analysis...")
            try:
                ast = type_check(ast)
            except TypeCheckError as e:
                self.log(f"\n[TYPE ERROR] Found {len(e.errors)} error(s):", "ERROR")
                for err in e.errors:
                    m = re.match(r"Line (\d+|\?): (.*)", err)
                    if m and m.group(1) != '?':
                        lineno = int(m.group(1))
                        msg = m.group(2)
                        syn_err = SyntaxError(msg)
                        syn_err.lineno = lineno
                        try:
                            debugger.display_syntax_error(syn_err, source=self.source_code, filename=str(self.source_file))
                        except Exception:
                            print(f"\033[31m[ERROR]\033[0m {err}", file=sys.stderr)
                    else:
                        print(f"\033[31m[ERROR]\033[0m {err}", file=sys.stderr)
                ans = input("\n\033[1;33mDo you want to continue compilation despite type errors? [y/N]: \033[0m").strip().lower()
                if ans not in ('y', 'yes'):
                    return False
            except Exception as e:
                self.log(f"  [!] Type check warning: {e}", "WARN")

            t_type = time.perf_counter()
            perf_times['Type Checker'] = t_type - t_opt

            self.log("\n[7/9] Static Memory Analysis...")
            mem_analyzer = StaticMemoryAnalyzer(debugger)
            ast = mem_analyzer.analyze(ast)

            t_mem = time.perf_counter()
            perf_times['Memory Analyzer'] = t_mem - t_type

            self.log("\n[8/9] Generating C code...")
            generator = CBLCodeEmitter(
                target="winlib" if self.is_dll else self.target,
                module_name=self.source_file.stem,
                source_filename=str(self.source_file.absolute().as_posix()),
                link_mode=self.link_mode,
                is_gui_app=self.is_gui_app
            )
            c_code = generator.generate(ast)

            with open(self.c_file, 'w', encoding='utf-8') as f: f.write(c_code)
            self.log(f"  Generated {len(c_code)} bytes of C code.")

            if self.gen_header:
                h_path = self.output_exe.with_suffix('.h')
                try:
                    with open(h_path, 'w', encoding='utf-8') as hf:
                        guard = h_path.stem.upper() + "_H"
                        hf.write(f"#ifndef {guard}\n#define {guard}\n\n")
                        hf.write("#include <stdint.h>\n#include <stdbool.h>\n\n")
                        hf.write("typedef struct {\n    char* data;\n    long length;\n} flux_string;\n\n")
                        for s in ast.structs:
                            if s.__class__.__name__ != 'EnumDef':
                                hf.write(f"typedef struct {s.name} {s.name};\n")
                        hf.write("\n")
                        for sig in getattr(generator, 'header_signatures', []):
                            hf.write(f"{sig}\n")
                        hf.write(f"\n#endif // {guard}\n")
                    self.log(f"  [+] Generated header: {h_path.name}")
                except Exception as e:
                    self.log(f"  [!] Failed to generate header: {e}", "WARN")

            t_gen = time.perf_counter()
            perf_times['Code Generation'] = t_gen - t_mem

            if self.asm_out:
                self.log("\n[9/9] Compiling C code to Assembly...")
            else:
                self.log("\n[9/9] Compiling C code to executable...")
                
            self.res_file = self._compile_resources()
            self._prepare_output_file()
            success = self._compile_c_to_exe()
            
            t_comp = time.perf_counter()
            perf_times['C Compiler'] = t_comp - t_gen
            perf_times['Total'] = t_comp - t_start
            
            if success:
                exe_p = self.output_exe if self.output_exe.exists() else self.output_exe.with_suffix('.exe')
                if exe_p.exists():
                    self.log(f"Final file size: {os.path.getsize(str(exe_p))/1024.0:.2f} KB")
                
                if not (self.keep_c or os.getenv('CBLERR_KEEP_C', '0') == '1'):
                    try:
                        if self.c_file.exists(): os.remove(self.c_file)
                        if self.obj_file.exists(): os.remove(self.obj_file)
                    except Exception as e:
                        self.log(f"Just a heads-up: couldn't clean up some temp files: {e}", "WARN")

                print("\033[92mCompilation successful!\033[0m")
                
                if self.profile_time:
                    print("\n\033[1;36m=== Profiling Results ===\033[0m")
                    for k, v in perf_times.items():
                        color = "\033[1;32m" if k == 'Total' else "\033[33m"
                        print(f"  {k.ljust(20)} : {color}{v * 1000:.2f} ms\033[0m")
                    print("\033[1;36m=========================\033[0m\n")

            return success

        except ParsingError as e:
            self.log(f"\n[PARSING ERROR] Found {len(e.errors)} error(s):", "ERROR")
            for err in e.errors:
                try: debugger.display_syntax_error(err, source=self.source_code, filename=str(self.source_file))
                except: print(f"[ERROR] {err}")
            return False
        except (SyntaxError, NameError) as e:
            if self.derr_flag:
                try: debugger.critical_dump(e)
                except: pass
                import traceback; traceback.print_exc()
            else:
                try: debugger.display_syntax_error(e, source=self.source_code, filename=str(self.source_file))
                except: print(f"[ERROR!] CODE ERROR: {e}")
            return False
        except Exception as e:
            try: debugger.critical_dump(e)
            except: pass
            self.log(f"[FATAL] {e}", "ERROR")
            import traceback; traceback.print_exc()
            return False
            
    def _compile_c_to_exe(self) -> bool:
        has_msvc = self._find_msvc_cl() is not None
        has_clang = self._compiler_exists('clang')
        has_gcc = self._compiler_exists('gcc')
        
        if platform.system() == 'Windows' and not has_gcc:
            if self._compiler_exists('i686-w64-mingw32-gcc') or self._compiler_exists('x86_64-w64-mingw32-gcc'):
                has_gcc = True
            elif Path(r"C:\msys64\mingw32\bin\gcc.exe").exists() or Path(r"C:\msys64\ucrt64\bin\gcc.exe").exists() or Path(r"C:\msys64\mingw64\bin\gcc.exe").exists():
                has_gcc = True

        if not (has_msvc or has_clang or has_gcc):
            self._print_compiler_installation_guide()
            return False

        sequence = []
        if self.target == 'wasm':
            if has_clang: sequence.append('clang')
            else:
                self.log("Target is Wasm, but Clang is not installed. Clang is required for Wasm.", "ERROR")
                self._print_compiler_installation_guide()
                return False
        elif self.target == 'linux':
            if platform.system() == 'Windows' or self.link_mode == 'static':
                if has_clang: sequence.append('clang')
                if has_gcc: sequence.append('gcc')
            else:
                if self.compiler_type == 'clang':
                    if has_clang: sequence.append('clang')
                    if has_gcc: sequence.append('gcc')
                else:
                    if has_gcc: sequence.append('gcc')
                    if has_clang: sequence.append('clang')
        elif self.target == 'windows':
            if self.compiler_type == 'gcc':
                if has_gcc: sequence.append('gcc')
                if has_clang: sequence.append('clang')
                if has_msvc: sequence.append('msvc')
            elif self.compiler_type == 'clang':
                if has_clang: sequence.append('clang')
                if has_gcc: sequence.append('gcc')
                if has_msvc: sequence.append('msvc')
            elif self.compiler_type == 'msvc':
                if has_msvc: sequence.append('msvc')
                if has_clang: sequence.append('clang')
                if has_gcc: sequence.append('gcc')
            else:
                if has_gcc: sequence.append('gcc')
                if has_clang: sequence.append('clang')
                if has_msvc: sequence.append('msvc')

        if not sequence:
            self._print_compiler_installation_guide()
            return False

        for i, comp in enumerate(sequence):
            is_last = (i == len(sequence) - 1)
            success = False
            
            if comp == 'msvc':
                success = self._compile_msvc()
            elif comp == 'clang':
                bare_metal = (self.target == 'linux' and (platform.system() == 'Windows' or self.link_mode == 'static'))
                success = self._compile_clang(bare_metal=bare_metal)
            elif comp == 'gcc':
                if self.target == 'windows':
                    success = self._compile_mingw()
                else:
                    success = self._compile_gcc()
                    
            if success:
                return True
            else:
                if not is_last:
                    self.log(f"\n[!] Compilation with {comp.upper()} failed. Falling back to the next compiler...", "WARN")
                
        return False

    def _compile_msvc(self) -> bool:
        self.log("Trying MSVC...")
        try:
            cl_exe = self._find_msvc_cl()
            if not cl_exe: return False
            
            srcs = [str(self.c_file)] + self.extra_files

            msvc_align = '/ALIGN:16'
            msvc_link_flags = f'/NODEFAULTLIB /LTCG /INCREMENTAL:NO /OPT:REF /OPT:ICF {msvc_align}'
            
            if self.m32:
                msvc_link_flags += ' /MACHINE:X86'
            else:
                msvc_link_flags += ' /MACHINE:X64'
                
            if self.is_dll:
                msvc_link_flags += ' /DLL /ENTRY:DllMainCRTStartup'
            else:
                msvc_link_flags += ' /SUBSYSTEM:WINDOWS' if self.is_gui_app else ' /SUBSYSTEM:CONSOLE'
                msvc_link_flags += ' /ENTRY:WinMainCRTStartup'
                
            if self.stack_reserve: msvc_link_flags += f' /STACK:{self.stack_reserve}'

            msvc_opt = '/O2 /Ot' if self.opt_level == '-O3' else '/O1 /Os'
            
            if getattr(self, 'avx_mode', None) == '512':
                msvc_opt += ' /arch:AVX512'
            elif getattr(self, 'avx_mode', None) == '256' or getattr(self, 'v3_mode', False):
                msvc_opt += ' /arch:AVX2'
            elif getattr(self, 'avx_mode', None) == '128':
                msvc_opt += ' /arch:AVX'
            elif self.m32:
                msvc_opt += ' /arch:SSE2'
            
            if self.asm_out:
                cmd = [cl_exe] + f'{msvc_opt} /GS- /GR- /Zc:threadSafeInit- /Oi /Gy /wd4047 /wd4024 /wd4311 /wd4312 /wd4244 /wd4090'.split() + srcs + [f'/Fa{self.output_exe}', '/c', '/FAs']
            else:
                cmd = [cl_exe] + f'{msvc_opt} /GS- /GR- /Zc:threadSafeInit- /Oi /Gy /wd4047 /wd4024 /wd4311 /wd4312 /wd4244 /wd4090'.split() + srcs + ([self.res_file] if self.res_file else []) + [f'/Fe{self.output_exe}', '/link'] + msvc_link_flags.split() + self._get_windows_libs('msvc')
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)

            if result.returncode == 0 and (self.output_exe.exists() or self.output_exe.with_suffix('.exe').exists() or self.output_exe.with_suffix('.scr').exists()):
                return True
                
            self.log(f"\n[!] Compiler output for MSVC:", "ERROR")
            self._handle_compile_error((result.stdout or "") + "\n" + (result.stderr or ""), self.debugger)
            return False
        except Exception as e: 
            self.log(f"Compiler execution failed: {e}", "ERROR")
            return False
    
    def _compile_clang(self, bare_metal: bool = False) -> bool:
        desc = "WebAssembly Build" if self.target == 'wasm' else ("optimized ELF build" if self.target == 'linux' and not bare_metal else "optimized freestanding PE/ELF build")
        self.log(f"Trying Clang ({desc})...")
        try:
            srcs = [str(self.c_file)] + self.extra_files
            cmd = [('clang.exe' if platform.system() == 'Windows' else 'clang')]
            
            if self.target == 'linux':
                cmd.append('--target=x86_64-linux-gnu')
                if bare_metal or platform.system() == 'Windows':
                    cmd.extend(['-ffreestanding', '-nostdlib', '-nostartfiles'])
                if platform.system() == 'Windows':
                    cmd.append('-fuse-ld=lld')
            elif self.target == 'wasm':
                cmd.append('--target=wasm32-unknown-unknown')
                cmd.append('-nostdlib')
            elif self.target == 'windows':
                target_triple = "i686-w64-mingw32" if self.m32 else "x86_64-w64-mingw32"
                cmd.append(f'--target={target_triple}')
                if platform.system() == 'Windows':
                    cmd.append('-fuse-ld=lld')
            
            cmd += self._get_compiler_flags('clang').split() + srcs + ([self.res_file] if self.res_file and not self.asm_out else [])
            
            if self.asm_out:
                cmd.append('-S')
                cmd.append('-masm=intel')
                
            cmd += ['-o', str(self.output_exe)]
            
            if not self.asm_out:
                cmd += self._get_linker_flags('clang').split()
                if self.target == 'linux':
                    if not bare_metal:
                        cmd.extend([
                            '-fno-unwind-tables',   
                            '-Wl,-s',               
                            '-Wl,--build-id=none',  
                            '-Wl,--no-rosegment'    
                        ])
                elif self.target == 'windows':
                    cmd.append('-Wl,-s')                 
                    cmd.extend(self._get_windows_libs('clang'))
                elif self.target == 'wasm':
                    cmd.extend([
                        '-mbulk-memory',
                        '-Wl,--no-entry',
                        '-Wl,--export-all',
                        '-Wl,--allow-undefined',
                        '-Wl,--import-memory'
                    ])
                
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            
            if result.returncode == 0:
                if self.target != 'windows' and not self.output_exe.exists() and self.output_exe.with_suffix('.exe').exists():
                    self.output_exe.with_suffix('.exe').replace(self.output_exe)
                return True
                
            self.log(f"\n[!] Compiler output for CLANG:", "ERROR")
            self._handle_compile_error((result.stdout or "") + "\n" + (result.stderr or ""), self.debugger)
            return False
        except Exception as e: 
            self.log(f"Compiler execution failed: {e}", "ERROR")
            return False

    def _compile_mingw(self) -> bool:
        self.log("Trying MinGW (gcc)...")
        try:
            srcs = [str(self.c_file)] + self.extra_files
            compiler_bin = 'gcc'
            env = os.environ.copy()
            
            if platform.system() == 'Windows':
                compiler_bin = 'gcc.exe'
                if self.m32:
                    if self._compiler_exists('i686-w64-mingw32-gcc'):
                        compiler_bin = 'i686-w64-mingw32-gcc'
                    elif Path(r"C:\msys64\mingw32\bin\gcc.exe").exists():
                        compiler_bin = r"C:\msys64\mingw32\bin\gcc.exe"
                        env["PATH"] = r"C:\msys64\mingw32\bin" + os.pathsep + env.get("PATH", "")
                else:
                    if self._compiler_exists('x86_64-w64-mingw32-gcc'):
                        compiler_bin = 'x86_64-w64-mingw32-gcc'
                    elif Path(r"C:\msys64\ucrt64\bin\gcc.exe").exists():
                        compiler_bin = r"C:\msys64\ucrt64\bin\gcc.exe"
                        env["PATH"] = r"C:\msys64\ucrt64\bin" + os.pathsep + env.get("PATH", "")
                    elif Path(r"C:\msys64\mingw64\bin\gcc.exe").exists():
                        compiler_bin = r"C:\msys64\mingw64\bin\gcc.exe"
                        env["PATH"] = r"C:\msys64\mingw64\bin" + os.pathsep + env.get("PATH", "")
            else:
                compiler_bin = 'i686-w64-mingw32-gcc' if self.m32 else 'x86_64-w64-mingw32-gcc'
                
            cmd = [compiler_bin] + self._get_compiler_flags('gcc').split() + srcs + ([self.res_file] if self.res_file and not self.asm_out else [])
            
            if self.asm_out:
                cmd.append('-S')
                cmd.append('-masm=intel')
                
            cmd += ['-o', str(self.output_exe)]
            
            if not self.asm_out:
                cmd += self._get_linker_flags('gcc').split() + self._get_windows_libs('gcc')
                
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=120, env=env)

            if result.returncode == 0 and (self.output_exe.exists() or self.output_exe.with_suffix('.exe').exists() or self.output_exe.with_suffix('.scr').exists()):
                return True
                
            self.log(f"\n[!] Compiler output for {compiler_bin.upper()}:", "ERROR")
            self._handle_compile_error((result.stdout or "") + "\n" + (result.stderr or ""), self.debugger)
            return False
        except Exception as e: 
            self.log(f"Compiler execution failed: {e}", "ERROR")
            return False

    def _compile_gcc(self) -> bool:
        self.log("Trying GCC (Linux)...")
        try:
            cmd = ['gcc'] + self._get_compiler_flags('gcc').split() + [str(self.c_file)] + self.extra_files
            
            if self.asm_out:
                cmd.append('-S')
                cmd.append('-masm=intel')
                
            cmd += ['-o', str(self.output_exe)]
            
            if not self.asm_out:
                cmd += self._get_linker_flags('gcc').split()
                
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            
            if result.returncode == 0:
                if self.target != 'windows' and not self.output_exe.exists() and self.output_exe.with_suffix('.exe').exists():
                    self.output_exe.with_suffix('.exe').replace(self.output_exe)
                return True
                
            self.log(f"\n[!] Compiler output for GCC:", "ERROR")
            self._handle_compile_error((result.stdout or "") + "\n" + (result.stderr or ""), self.debugger)
            return False
        except Exception as e: 
            self.log(f"Compiler execution failed: {e}", "ERROR")
            return False

    def _find_msvc_cl(self) -> Optional[str]:
        target_arch = "x86" if self.m32 else "x64"
        for path in [
            rf"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.39.33519\bin\Hostx64\{target_arch}\cl.exe",
            rf"C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.29.30133\bin\Hostx64\{target_arch}\cl.exe",
            rf"C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Tools\MSVC\14.39.33519\bin\Hostx64\{target_arch}\cl.exe",
            rf"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.39.33519\bin\Hostx86\{target_arch}\cl.exe",
            rf"C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.29.30133\bin\Hostx86\{target_arch}\cl.exe",
            rf"C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Tools\MSVC\14.39.33519\bin\Hostx86\{target_arch}\cl.exe",
        ]:
            if Path(path).exists(): return path
        try:
            res = subprocess.run(['where', 'cl.exe'], capture_output=True, text=True)
            if res.returncode == 0: return res.stdout.strip().split('\n')[0]
        except: pass
        return None

    def _handle_compile_error(self, error_output: str, debugger) -> None:
        try:
            if "undefined reference" in error_output or "ld returned 1" in error_output:
                print(f"\n\033[31m[LINKER ERROR]\033[0m\n{error_output.strip()}", file=sys.stderr)
                return

            cbl_source = open(self.source_file, 'r', encoding='utf-8').read() if self.source_file.exists() else None
            c_source = open(self.c_file, 'r', encoding='utf-8').read() if self.c_file.exists() else None
            
            m_loc = re.search(r"(.*?\.c(?:bl)?):(\d+):(?:\d+:)?\s*(?:fatal )?error:\s*(.+)", error_output, flags=re.I)
            m_msg = re.search(r"(?:error):\s*(.+?)(?:\n|$)", error_output, flags=re.I)
            
            if m_loc:
                filename = m_loc.group(1)
                line = int(m_loc.group(2))
                msg = m_loc.group(3).strip()
                err = SyntaxError(msg)
                err.lineno = line
                err.filename = filename
                
                if filename.endswith('.cbl') and cbl_source:
                    debugger.display_syntax_error(err, source=cbl_source, filename=filename)
                elif c_source:
                    debugger.display_syntax_error(err, source=c_source, filename=filename)
                else:
                    print(f"[ERROR] {filename}:{line} - {msg}", file=sys.stderr)
                return
            elif m_msg:
                if cbl_source:
                    debugger.display_syntax_error(SyntaxError(m_msg.group(1).strip()), source=cbl_source, filename=str(self.source_file))
                else: 
                    print(f"[ERROR] {m_msg.group(1).strip()}", file=sys.stderr)
                return
        except Exception: 
            pass
        
        if error_output.strip():
            print(f"\n\033[31m[C COMPILER RAW ERROR]\033[0m\n{error_output.strip()}", file=sys.stderr)