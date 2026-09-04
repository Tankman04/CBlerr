from core.flux_ast import *

class Formatter:
    def __init__(self):
        self.indent_level = 0
        self.output = []

    def emit(self, text):
        self.output.append("    " * self.indent_level + text)

    def _type_to_str(self, t: Any) -> str:
        if t is None: return "void"
        if isinstance(t, str): return t
        
        cname = getattr(t, '__class__', None).__name__ if t else ""
        if cname == 'GenericType':
            args = ', '.join(self._type_to_str(a) for a in getattr(t, 'args', []))
            return f"{getattr(t, 'name', '')}<{args}>"
        if cname == 'PointerType':
            return f"*{self._type_to_str(getattr(t, 'base_type', 'void'))}"
        return str(t)

    def format(self, program: Program) -> str:
        for imp in program.imports:
            if isinstance(imp, ImportStmt):
                self.emit(f"import {imp.module_name}")
            elif isinstance(imp, FromImportStmt):
                items = ", ".join(filter(None, imp.items))
                self.emit(f"from {imp.module_name} import {items}")
        if program.imports:
            self.output.append("")

        for g in program.global_vars:
            c = "const " if g.is_const else "let "
            t = f": {self._type_to_str(g.var_type)}" if getattr(g, 'var_type', None) else ""
            val = f" = {self.format_expr(g.value)}" if g.value else ""
            self.emit(f"{c}{g.name}{t}{val}")
        if program.global_vars:
            self.output.append("")

        for s in program.structs:
            if getattr(s, 'decorators', None):
                for dec in s.decorators:
                    args = f"({', '.join(dec.args)})" if dec.args else ""
                    self.emit(f"@{dec.name}{args}")
            
            if getattr(s, '__class__', None).__name__ == 'EnumDef':
                self.emit(f"enum {s.name}:")
                self.indent_level += 1
                if not s.members:
                    self.emit("pass")
                for mname, mval in s.members:
                    if mval:
                        self.emit(f"{mname} = {self.format_expr(mval)}")
                    else:
                        self.emit(mname)
                self.indent_level -= 1
            else:
                self.emit(f"struct {s.name}:")
                self.indent_level += 1
                fields = s.fields.items() if isinstance(s.fields, dict) else s.fields
                if not fields:
                    self.emit("pass")
                for fname, ftype in fields:
                    self.emit(f"{fname}: {self._type_to_str(ftype)}")
                self.indent_level -= 1
            self.output.append("")

        for func in program.functions:
            if getattr(func, 'decorators', None):
                for dec in func.decorators:
                    args = f"({', '.join(dec.args)})" if dec.args else ""
                    self.emit(f"@{dec.name}{args}")

            if getattr(func, 'is_extern', False):
                params = ", ".join(f"{n}: {self._type_to_str(t)}" for n, t in func.params)
                ret = f" -> {self._type_to_str(func.return_type)}" if func.return_type and func.return_type != 'void' else ""
                self.emit(f"extern def {func.name}({params}){ret}")
                continue

            params = ", ".join(f"{n}: {self._type_to_str(t)}" for n, t in func.params)
            if getattr(func, 'is_vararg', False):
                params += ", ..." if params else "..."
            ret = f" -> {self._type_to_str(func.return_type)}" if func.return_type and func.return_type != 'void' else ""
            
            self.emit(f"def {func.name}({params}){ret}:")
            self.indent_level += 1
            if not func.body:
                self.emit("pass")
            for stmt in func.body:
                self.format_stmt(stmt)
            self.indent_level -= 1
            self.output.append("")

        return "\n".join(self.output)

    def format_stmt_inline(self, stmt) -> str:
        if not stmt: return ""
        cname = stmt.__class__.__name__
        if cname == 'Assign':
            t = f": {self._type_to_str(stmt.var_type)}" if getattr(stmt, 'var_type', None) else ""
            tgt = stmt.target if isinstance(stmt.target, str) else getattr(stmt.target, 'name', self.format_expr(stmt.target))
            val = f" = {self.format_expr(stmt.value)}" if getattr(stmt, 'value', None) else ""
            if not isinstance(stmt.target, str) and not hasattr(stmt.target, 'name'):
                return f"{tgt}{val}"
            else:
                if t:
                    return f"let {tgt}{t}{val}"
                else:
                    return f"{tgt}{val}"
        return self.format_expr(stmt)

    def _format_if_stmt(self, stmt, is_elif=False):
        keyword = "elif" if is_elif else "if"
        self.emit(f"{keyword} {self.format_expr(stmt.condition)}:")
        self.indent_level += 1
        if not stmt.then_body:
            self.emit("pass")
        for s in stmt.then_body: self.format_stmt(s)
        self.indent_level -= 1
        
        if getattr(stmt, 'else_body', None):
            if len(stmt.else_body) == 1 and stmt.else_body[0].__class__.__name__ == 'IfStmt':
                self._format_if_stmt(stmt.else_body[0], is_elif=True)
            else:
                self.emit("else:")
                self.indent_level += 1
                if not stmt.else_body:
                    self.emit("pass")
                for s in stmt.else_body: self.format_stmt(s)
                self.indent_level -= 1

    def format_stmt(self, stmt):
        cname = stmt.__class__.__name__
        if cname == 'Return':
            self.emit(f"return {self.format_expr(stmt.value)}" if stmt.value else "return")
        elif cname == 'Assign':
            t = f": {self._type_to_str(stmt.var_type)}" if getattr(stmt, 'var_type', None) else ""
            if isinstance(stmt.target, str):
                tgt = stmt.target
            elif hasattr(stmt.target, 'name'):
                tgt = stmt.target.name
            else:
                tgt = self.format_expr(stmt.target)
            
            if not isinstance(stmt.target, str) and not hasattr(stmt.target, 'name'):
                self.emit(f"{tgt} = {self.format_expr(stmt.value)}")
            else:
                if t:
                    if getattr(stmt, 'value', None):
                        self.emit(f"let {tgt}{t} = {self.format_expr(stmt.value)}")
                    else:
                        self.emit(f"let {tgt}{t}")
                else:
                    self.emit(f"{tgt} = {self.format_expr(stmt.value)}")
        elif cname == 'Call':
            self.emit(self.format_expr(stmt))
        elif cname == 'BreakStmt':
            self.emit("break")
        elif cname == 'ContinueStmt':
            self.emit("continue")
        elif cname == 'WhileLoop':
            self.emit(f"while {self.format_expr(stmt.condition)}:")
            self.indent_level += 1
            if not stmt.body:
                self.emit("pass")
            for s in stmt.body: self.format_stmt(s)
            self.indent_level -= 1
        elif cname == 'IfStmt':
            self._format_if_stmt(stmt)
        elif cname == 'ForLoop':
            if getattr(stmt, 'iter_var', None):
                self.emit(f"for {stmt.iter_var} in {self.format_expr(stmt.iter_expr)}:")
            else:
                init = self.format_stmt_inline(stmt.init) if getattr(stmt, 'init', None) else ""
                cond = self.format_expr(stmt.condition) if getattr(stmt, 'condition', None) else ""
                post = self.format_stmt_inline(stmt.post) if getattr(stmt, 'post', None) else ""
                self.emit(f"for ({init}; {cond}; {post}):")
            self.indent_level += 1
            if not getattr(stmt, 'body', None):
                self.emit("pass")
            for s in stmt.body: self.format_stmt(s)
            self.indent_level -= 1
        elif cname == 'MatchStmt':
            self.emit(f"match {self.format_expr(stmt.expr)}:")
            self.indent_level += 1
            for case in stmt.cases:
                if case.values:
                    vals = ", ".join(self.format_expr(v) for v in case.values)
                    self.emit(f"case {vals}:")
                else:
                    self.emit("default:")
                self.indent_level += 1
                if not case.body:
                    self.emit("pass")
                for s in case.body: self.format_stmt(s)
                self.indent_level -= 1
            self.indent_level -= 1
        elif cname == 'DeferStmt':
            self.emit("defer:")
            self.indent_level += 1
            if not stmt.body:
                self.emit("pass")
            for s in stmt.body: self.format_stmt(s)
            self.indent_level -= 1
        elif cname == 'InlineAsm':
            code = stmt.code.replace('\\', '\\\\').replace('\n', '\\n').replace('"', '\\"')
            self.emit(f'asm("{code}")')
        else:
            formatted = self.format_expr(stmt)
            if formatted:
                self.emit(formatted)

    def format_expr(self, expr) -> str:
        if not expr: return ""
        cname = expr.__class__.__name__
        if cname == 'Literal':
            if expr.type == 'str': 
                val = expr.value.replace('\\', '\\\\').replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t').replace('"', '\\"')
                return f'"{val}"'
            if expr.type == 'bool': return "true" if expr.value else "false"
            return str(expr.value)
        if cname == 'Variable': return expr.name
        if cname == 'Call':
            args = ", ".join(self.format_expr(a) for a in getattr(expr, 'args', []))
            fname = expr.func_name if isinstance(expr.func_name, str) else getattr(expr.func_name, 'name', self.format_expr(expr.func_name))
            type_args_str = ""
            if getattr(expr, 'type_args', None):
                type_args_str = "<" + ", ".join(self._type_to_str(t) for t in expr.type_args) + ">"
            return f"{fname}{type_args_str}({args})"
        if cname == 'BinaryOp': return f"{self.format_expr(expr.left)} {expr.op} {self.format_expr(expr.right)}"
        if cname == 'Compare': return f"{self.format_expr(expr.left)} {expr.op} {self.format_expr(expr.right)}"
        if cname == 'LogicalOp':
            if expr.op == 'not': return f"not {self.format_expr(expr.left)}"
            return f"{self.format_expr(expr.left)} {expr.op} {self.format_expr(expr.right)}"
        if cname == 'FieldAccess': return f"{self.format_expr(expr.obj)}.{expr.field}"
        if cname == 'ArrayAccess': return f"{self.format_expr(expr.arr)}[{self.format_expr(expr.index)}]"
        if cname == 'AddressOf': return f"&{self.format_expr(expr.expr)}"
        if cname == 'Dereference': return f"*{self.format_expr(expr.ptr)}"
        if cname == 'ArrayLiteral':
            elems = ", ".join(self.format_expr(e) for e in expr.elements)
            if getattr(expr, 'is_struct_init', False): return f"{{{elems}}}"
            return f"[{elems}]"
        if cname == 'CastExpr': return f"{self.format_expr(expr.expr)} as {self._type_to_str(expr.target_type)}"
        if cname == 'SizeOf': return f"sizeof({self._type_to_str(expr.target)})"
        if cname == 'WalrusExpr': return f"{self.format_expr(expr.target)} := {self.format_expr(expr.value)}"
        return str(expr)