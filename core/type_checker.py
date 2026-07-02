from typing import Any, Dict, Optional, Set
from core.flux_ast import (
    Program, FunctionDef, Return, BinaryOp, Variable, Literal,
    IfStmt, Assign, Compare, Call, WhileLoop, BreakStmt, ContinueStmt,
    StructDef, FieldAccess, ArrayAccess, ArrayLiteral, LogicalOp,
    Dereference, InlineAsm, CastExpr, AddressOf, SizeOf,
    WalrusExpr, ForLoop, MatchStmt, EnumDef, GlobalVariable, DeferStmt
)
from core.debugger import get_debugger

class TypeCheckError(Exception): 
    def __init__(self, errors):
        self.errors = errors
        super().__init__(f"Type checking failed with {len(errors)} error(s)")

class ParsingError(Exception): pass

ALLOWED_TYPES = {
    'int', 'int32', 'int64', 'bool', 'char', 'void', 'ptr',
    'float', 'f32', 'f64', 
    'i8', 'i16', 'i32', 'i64', 
    'u8', 'u16', 'u32', 'u64', 
    'str', 'string', 'flux_string'
}

BUILTIN_SIGS = {
    'bump': ('*void', [('size', 'int')]),
    'malloc': ('*void', [('size', 'int')]),
    'free': ('void', [('ptr', '*void')]),
    'memset': ('*void', [('dest', '*void'), ('val', 'int'), ('count', 'int')]),
    'memcpy': ('*void', [('dest', '*void'), ('src', '*void'), ('count', 'int')]),
    'memmove': ('*void', [('dest', '*void'), ('src', '*void'), ('count', 'int')]),
    'memcmp': ('int', [('s1', '*void'), ('s2', '*void'), ('count', 'int')]),
    'strcmp': ('int', [('s1', 'str'), ('s2', 'str')]),
    'strlen': ('int', [('s', '*char')]),
    'sin': ('float', [('x', 'float')]),
    'cos': ('float', [('x', 'float')]),
    'tan': ('float', [('x', 'float')]),
    'asin': ('float', [('x', 'float')]),
    'acos': ('float', [('x', 'float')]),
    'atan': ('float', [('x', 'float')]),
    'atan2': ('float', [('y', 'float'), ('x', 'float')]),
    'log': ('float', [('x', 'float')]),
    'exp': ('float', [('x', 'float')]),
    'pow': ('float', [('x', 'float'), ('y', 'float')]),
    'sqrt': ('float', [('x', 'float')]),
    'floor': ('float', [('x', 'float')]),
    'ceil': ('float', [('x', 'float')]),
    'fmod': ('float', [('x', 'float'), ('y', 'float')]),
    'abs': ('int', [('x', 'int')]),
    'fabs': ('float', [('x', 'float')]),
    'rand': ('int', []),
    'srand': ('void', [('seed', 'int')]),
    'time': ('i64', [('dummy', '*void')]),
    'clock': ('int', []),
    'printf': ('int', [('fmt', '*char')]),
    'sprintf': ('int', [('buf', '*char'), ('fmt', '*char')]),
    'scanf': ('int', [('fmt', '*char')]),
    'puts': ('int', [('s', '*char')]),
}

class SymbolTable:
    def __init__(self, parent=None):
        self.vars: Dict[str, str] = {}
        self.read_vars: Set[str] = set()
        self.parent = parent

    def declare(self, name: str, t: str):
        self.vars[name] = t

    def lookup(self, name: str) -> Optional[str]:
        if name in self.vars:
            self.read_vars.add(name)
            return self.vars[name]
        if self.parent:
            return self.parent.lookup(name)
        return None

class TypeChecker:
    def __init__(self):
        self.global_env = SymbolTable()
        self.functions: Dict[str, FunctionDef] = {}
        self.structs: Dict[str, StructDef] = {}
        self.enums: Dict[str, EnumDef] = {}
        self.current_func: Optional[FunctionDef] = None
        self.env = self.global_env
        self.debugger = get_debugger()
        self.errors = []
        self.program = None

    def report_error(self, msg: str, node: Any = None):
        line = getattr(node, 'line', '?')
        if line == 0: line = '?'
        self.errors.append(f"Line {line}: {msg}")

    def enter_scope(self):
        self.env = SymbolTable(self.env)

    def leave_scope(self):
        for var_name in self.env.vars:
            if var_name not in self.env.read_vars and not var_name.startswith('_'):
                self.debugger.log_warning(f"Unused variable: '{var_name}' was declared but never read.")
                
        if self.env.parent:
            self.env = self.env.parent

    def _resolve_type_name(self, t: Any) -> str:
        if t is None: return "void"
        if type(t) is str: return t
        
        cname = t.__class__.__name__
        if cname == 'PointerType':
            return f"*{self._resolve_type_name(t.base_type)}"
        if cname == 'GenericType':
            args = ",".join(self._resolve_type_name(a) for a in getattr(t, 'args', []))
            return f"{getattr(t, 'name', '')}<{args}>"
            
        return str(t)

    def validate_type(self, type_name: str, node: Any = None):
        if not type_name or type_name == "void": return
        base_type = type_name.lstrip('*')
        
        if base_type.startswith('ptr<') or base_type == 'ptr': 
            return
            
        if base_type not in ALLOWED_TYPES and base_type not in self.structs and base_type not in self.enums:
            self.report_error(f"Invalid type used: '{base_type}' is not allowed or not defined.", node)

    def check_type_compatibility(self, t1: str, t2: str, op: str, node: Any = None):
        is_ptr1 = t1.startswith('*') or 'ptr' in t1
        is_ptr2 = t2.startswith('*') or 'ptr' in t2
        
        if is_ptr1 and is_ptr2 and op in ('+', '-', '*', '/'):
            self.report_error("Pointer arithmetic is restricted.", node)
            
        if (is_ptr1 or is_ptr2) and op in ('*', '/', '%', '**', '<<', '>>', '&', '|', '^'):
            self.report_error(f"Invalid operation '{op}' with pointer type. Explicit cast to int is required.", node)
            
        if op in ('+', '-'):
            valid_ints = ('int', 'int32', 'int64', 'i8', 'i16', 'i32', 'i64', 'u8', 'u16', 'u32', 'u64')
            if is_ptr1 and not is_ptr2 and t2 not in valid_ints:
                self.report_error(f"Cannot perform '{op}' on pointer and '{t2}'.", node)
            if is_ptr2 and not is_ptr1 and t1 not in valid_ints:
                self.report_error(f"Cannot perform '{op}' on '{t1}' and pointer.", node)

    def check(self, program: Program) -> Program:
        self.program = program
        
        for s in program.structs:
            if s.__class__.__name__ == 'EnumDef':
                self.enums[s.name] = s
            else:
                self.structs[s.name] = s

        for g in program.global_vars:
            t = self._resolve_type_name(g.var_type)
            self.validate_type(t, g)
            self.global_env.declare(g.name, t)

        for f in program.functions:
            if getattr(f, 'is_extern', False) and f.name in BUILTIN_SIGS:
                ret_type, params = BUILTIN_SIGS[f.name]
                f.params = params
                f.return_type = ret_type
            self.functions[f.name] = f

        for g in program.global_vars:
            if g.value:
                val_t = self.check_expr(g.value)
                if getattr(g, 'var_type', None) is None:
                    g.var_type = val_t
                    self.validate_type(val_t, g)
                    self.global_env.declare(g.name, val_t)

        for f in program.functions:
            if getattr(f, 'is_extern', False):
                continue
                
            self.current_func = f
            self.enter_scope()
            
            if f.params:
                for pname, ptype in f.params:
                    if isinstance(pname, str):
                        res_t = self._resolve_type_name(ptype)
                        self.validate_type(res_t, f)
                        self.env.declare(pname, res_t)
            
            if f.body:
                for stmt in f.body:
                    self.check_stmt(stmt)
                
            self.leave_scope()
            self.current_func = None

        if self.errors:
            raise TypeCheckError(self.errors)

        return program

    def check_stmt(self, stmt: Any):
        cname = stmt.__class__.__name__
        
        if cname == 'Return':
            if stmt.value:
                self.check_expr(stmt.value)
                if stmt.value.__class__.__name__ == 'ArrayLiteral':
                    self.report_error("Cannot return a local array by value (Undefined Behavior). Use dynamic allocation.", stmt)
                
        elif cname == 'Assign':
            if getattr(stmt, 'var_type', None):
                t = self._resolve_type_name(stmt.var_type)
                self.validate_type(t, stmt)
                if isinstance(stmt.target, str):
                    self.env.declare(stmt.target, t)
                elif stmt.target.__class__.__name__ == 'Variable':
                    self.env.declare(stmt.target.name, t)
            
            val_t = self.check_expr(stmt.value)
            
            if isinstance(stmt.target, str):
                if not self.env.lookup(stmt.target):
                    self.env.declare(stmt.target, val_t)
                    stmt.var_type = val_t  
            elif stmt.target.__class__.__name__ == 'Variable':
                if not self.env.lookup(stmt.target.name):
                    self.env.declare(stmt.target.name, val_t)
                    stmt.var_type = val_t  
                self.check_expr(stmt.target)
            else:
                self.check_expr(stmt.target)
                
        elif cname == 'IfStmt':
            self.check_expr(stmt.condition)
            self.enter_scope()
            for s in stmt.then_body: self.check_stmt(s)
            self.leave_scope()
            if stmt.else_body:
                self.enter_scope()
                for s in stmt.else_body: self.check_stmt(s)
                self.leave_scope()
                
        elif cname == 'WhileLoop':
            self.check_expr(stmt.condition)
            self.enter_scope()
            for s in stmt.body: self.check_stmt(s)
            self.leave_scope()
            
        elif cname == 'ForLoop':
            self.enter_scope()
            if stmt.init: self.check_stmt(stmt.init)
            if getattr(stmt, 'iter_var', None):
                self.env.declare(stmt.iter_var, "int")
            if stmt.condition: self.check_expr(stmt.condition)
            if stmt.post: self.check_stmt(stmt.post)
            if stmt.iter_expr: self.check_expr(stmt.iter_expr)
            for s in stmt.body: self.check_stmt(s)
            self.leave_scope()
            
        elif cname == 'MatchStmt':
            self.check_expr(stmt.expr)
            for case in stmt.cases:
                self.enter_scope()
                if case.values:
                    for v in case.values: self.check_expr(v)
                for s in case.body: self.check_stmt(s)
                self.leave_scope()
                
        elif cname == 'DeferStmt':
            for s in stmt.body:
                self.check_stmt(s)
                
        elif cname == 'Call':
            self.check_expr(stmt)
            
        elif cname in ('BreakStmt', 'ContinueStmt', 'InlineAsm'):
            pass
            
        else:
            self.check_expr(stmt)

    def check_expr(self, expr: Any) -> str:
        if expr is None: return "void"
        t = "void"
        
        cname = expr.__class__.__name__

        if cname == 'Literal':
            t = expr.type
            
        elif cname == 'Variable':
            looked_up = self.env.lookup(expr.name)
            if looked_up:
                t = looked_up
            elif expr.name in self.functions:
                t = "fn"
            elif expr.name in BUILTIN_SIGS:
                ret_type, params = BUILTIN_SIGS[expr.name]
                is_vararg = expr.name in ('printf', 'sprintf', 'scanf')
                fdef = FunctionDef(expr.name, params, ret_type, [], is_extern=True, is_vararg=is_vararg)
                self.functions[expr.name] = fdef
                self.program.functions.append(fdef)
                t = "fn"
            else:
                self.global_env.declare(expr.name, "int")
                t = "int"
                
        elif cname == 'BinaryOp':
            lt = self.check_expr(expr.left)
            rt = self.check_expr(expr.right)
            self.check_type_compatibility(lt, rt, expr.op, expr)
            
            t = lt if lt != "void" else (rt if rt != "void" else "int")
            if expr.op in ('<<', '>>', '&', '|', '^', '%'): t = "int"
            if expr.op in ('/', '**') and lt in ('float', 'f32', 'f64', 'double'): t = lt
            
        elif cname == 'Compare':
            self.check_expr(expr.left)
            self.check_expr(expr.right)
            t = "bool"
            
        elif cname == 'LogicalOp':
            self.check_expr(expr.left)
            if expr.right: self.check_expr(expr.right)
            t = "bool"
            
        elif cname == 'Call':
            fname = expr.func_name if isinstance(expr.func_name, str) else getattr(expr.func_name, 'name', '')
            if fname in self.functions:
                f = self.functions[fname]
                t = self._resolve_type_name(f.return_type)
                
                expected_args = len(f.params)
                args_len = len(expr.args) if expr.args else 0
                if f.is_vararg:
                    if args_len < expected_args:
                        self.report_error(f"Function '{fname}' expects at least {expected_args} arguments, got {args_len}.", expr)
                else:
                    if args_len != expected_args:
                        self.report_error(f"Function '{fname}' expects {expected_args} arguments, got {args_len}.", expr)
                        
                for i, arg in enumerate(expr.args or []):
                    arg_t = self.check_expr(arg)
                    if i < expected_args:
                        expected_t = self._resolve_type_name(f.params[i][1])
                        if arg_t != expected_t and expected_t != "void" and arg_t != "void":
                            if expected_t == '*void' and arg_t.startswith('*'): continue
                            if arg_t == '*void' and expected_t.startswith('*'): continue
                            if expected_t == 'ptr' and arg_t.startswith('*'): continue
                            if arg_t == 'ptr' and expected_t.startswith('*'): continue
                            if arg_t in ('int','i32','i64') and expected_t in ('int','i32','i64'): continue
                            if arg_t in ('float','f32','f64') and expected_t in ('float','f32','f64'): continue
                            self.report_error(f"Type mismatch in argument {i+1} for '{fname}': expected '{expected_t}', got '{arg_t}'.", expr)
                            
            elif fname in BUILTIN_SIGS:
                ret_type, params = BUILTIN_SIGS[fname]
                is_vararg = fname in ('printf', 'sprintf', 'scanf')
                fdef = FunctionDef(fname, params, ret_type, [], is_extern=True, is_vararg=is_vararg)
                self.functions[fname] = fdef
                self.program.functions.append(fdef)
                t = self._resolve_type_name(ret_type)
                
                for arg in (expr.args or []):
                    self.check_expr(arg)
            elif fname == 'len':
                for arg in (expr.args or []): self.check_expr(arg)
                t = 'int'
            elif fname in ('print', 'range'):
                for arg in (expr.args or []): self.check_expr(arg)
                t = 'void'
            else:
                fdef = FunctionDef(fname, [], 'int', [], is_extern=True, is_vararg=True)
                self.functions[fname] = fdef
                self.program.functions.append(fdef)
                t = "int"
                
            for arg in (expr.args or []):
                arg_t = getattr(arg, 'resolved_type', "int")
                if arg_t in self.structs:
                    sdef = self.structs[arg_t]
                    if len(sdef.fields) > 4:
                        self.debugger.log_warning(f"Performance: Passing heavy struct '{arg_t}' by value to '{fname}'. Consider passing as *{arg_t}.")
                
        elif cname == 'ArrayAccess':
            arr_t = self.check_expr(expr.arr)
            self.check_expr(expr.index)
            if arr_t.startswith('*'): t = arr_t[1:]
            elif arr_t.endswith('*'): t = arr_t[:-1]
            elif arr_t in ('str', 'string', 'flux_string'): t = 'char'
            else: 
                t = arr_t
                if not t.startswith('*'):
                    self.report_error(f"InvalidTypeError: Cannot index into non-array/non-pointer type '{arr_t}'", expr)
            
        elif cname == 'FieldAccess':
            obj_t = self.check_expr(expr.obj)
            base = obj_t.lstrip('*')
            
            if base in ('str', 'string', 'flux_string'):
                if expr.field == 'data': t = '*char'
                elif expr.field == 'length': t = 'int'
                else: 
                    self.report_error(f"UndefinedSymbolError: Field '{expr.field}' is not defined on type string.", expr)
                    t = "int"
            elif base in self.structs:
                fields = self.structs[base].fields
                found = False
                if isinstance(fields, dict):
                    if expr.field in fields:
                        t = self._resolve_type_name(fields[expr.field])
                        found = True
                else:
                    for fname, ftype in fields:
                        if fname == expr.field:
                            t = self._resolve_type_name(ftype)
                            found = True
                            break
                if not found:
                    self.report_error(f"UndefinedSymbolError: Struct '{base}' has no field '{expr.field}'.", expr)
                    t = "int"
            else:
                self.report_error(f"InvalidTypeError: Type '{base}' is not a struct, cannot access field '{expr.field}'.", expr)
                t = "int"
                            
        elif cname == 'Dereference':
            ptr_t = self.check_expr(expr.ptr)
            if isinstance(ptr_t, str):
                if ptr_t.startswith('*'):
                    t = ptr_t[1:]
                elif ptr_t.startswith('ptr<') and ptr_t.endswith('>'):
                    t = ptr_t[4:-1]
                elif ptr_t == 'ptr':
                    t = 'void'
                else:
                    self.report_error(f"InvalidTypeError: Cannot dereference non-pointer type '{ptr_t}'.", expr)
                    t = "int"
            else:
                if ptr_t.__class__.__name__ == 'PointerType':
                    t = self._resolve_type_name(getattr(ptr_t, 'base_type', 'void'))
                else:
                    self.report_error(f"InvalidTypeError: Cannot dereference non-pointer type '{ptr_t}'.", expr)
                    t = "int"
            
        elif cname == 'AddressOf':
            inner_t = self.check_expr(expr.expr)
            t = f"*{inner_t}"
            
        elif cname == 'CastExpr':
            self.check_expr(expr.expr)
            t = self._resolve_type_name(expr.target_type)
            self.validate_type(t, expr)
            
        elif cname == 'SizeOf':
            t = "int"
            
        elif cname == 'ArrayLiteral':
            elem_t = "int"
            if expr.elements:
                elem_t = self.check_expr(expr.elements[0])
                for e in expr.elements[1:]: self.check_expr(e)
            t = getattr(expr, 'array_type', None)
            if not t: 
                t = f"*{elem_t}"
            elif not isinstance(t, str): 
                t = self._resolve_type_name(t)
                self.validate_type(t, expr)
                
        elif cname == 'WalrusExpr':
            self.check_expr(expr.target)
            val_t = self.check_expr(expr.value)
            
            target_name = expr.target if isinstance(expr.target, str) else getattr(expr.target, 'name', None)
            if target_name:
                if not self.env.lookup(target_name):
                    self.env.declare(target_name, val_t)
            t = val_t

        if hasattr(expr, '__dict__'):
            expr.resolved_type = t
            
        return t

def type_check(program: Program) -> Program:
    return TypeChecker().check(program)