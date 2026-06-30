
from typing import Any, List
from core.lexer import Token, TokenType
from core.flux_ast import (
    Program, FunctionDef, Return, BinaryOp, Variable, Literal,
    IfStmt, Assign, Compare, Call, WhileLoop, BreakStmt, ContinueStmt,
    StructDef, FieldAccess, ArrayAccess, ArrayLiteral, LogicalOp,
    PointerType, Dereference, InlineAsm, CastExpr, Decorator, ComptimeBlock,
    MatchStmt, Case, ForLoop, EnumDef, AddressOf, SizeOf, GenericType,
    ImportStmt, FromImportStmt, WalrusExpr, GlobalVariable, DeferStmt
)
from core.debugger import get_debugger

class ParsingError(Exception):
    def __init__(self, errors):
        self.errors = errors
        super().__init__(f"Parsing failed with {len(errors)} error(s)")

class Parser:
    def __init__(self, tokens: List[Token]):
        self.tokens = tokens
        self._len_tokens = len(tokens)
        self.pos = 0
        self.debugger = get_debugger()
        self.errors = []

    def current_token(self) -> Token | None:
        return self.tokens[self.pos] if self.pos < self._len_tokens else None

    def peek_token(self, offset: int = 1) -> Token | None:
        idx = self.pos + offset
        return self.tokens[idx] if idx < self._len_tokens else None

    def advance(self) -> Token | None:
        if self.pos < self._len_tokens:
            t = self.tokens[self.pos]
            self.pos += 1
            return t
        return None

    def expect(self, token_type: TokenType, error_msg: str = None, strict: bool = True):
        token = self.current_token()
        if not token or token.type != token_type:
            msg = error_msg or f"Expected {token_type}, got {token.type if token else 'EOF'}"
            if strict:
                err = SyntaxError(f"{msg} at line {token.line if token else '?'}")
                err.lineno = token.line if token else 0
                raise err
            else:
                self.debugger.log_warning(msg)
                return token
        return self.advance()

    def skip_newlines(self) -> None:
        while self.pos < self._len_tokens and self.tokens[self.pos].type == TokenType.NEWLINE:
            self.pos += 1

    def synchronize(self):
        self.advance()
        while self.pos < self._len_tokens and self.tokens[self.pos].type not in (
            TokenType.NEWLINE, TokenType.DEF, TokenType.STRUCT, TokenType.ENUM, 
            TokenType.LET, TokenType.IF, TokenType.WHILE, TokenType.FOR, 
            TokenType.RETURN, TokenType.MATCH, TokenType.EOF, TokenType.EXTERN,
            TokenType.CONST, TokenType.DEFER
        ):
            self.advance()

    def parse_type(self) -> Any:
        token = self.current_token()
        if token is None:
            raise SyntaxError("Expected type, but reached EOF")

        if token.type == TokenType.MULTIPLY:
            star_count = 0
            while self.current_token() and self.current_token().type == TokenType.MULTIPLY:
                star_count += 1
                self.advance()
            base = self.parse_type()
            result = base
            for _ in range(star_count): result = f"*{result}"
            return result

        type_tokens = {
            TokenType.NAME, TokenType.INT, TokenType.STR, TokenType.BOOL, TokenType.FLOAT, TokenType.VOID,
            TokenType.U8, TokenType.U16, TokenType.U32, TokenType.U64,
            TokenType.I8, TokenType.I16, TokenType.I32, TokenType.I64,
        }

        if token.type in type_tokens:
            name = token.value if getattr(token, 'value', None) is not None else token.type.name.lower()
            self.advance()

            if self.current_token() and self.current_token().type == TokenType.LT:
                self.advance()
                args: list[Any] = []
                while True:
                    args.append(self.parse_type())
                    if self.current_token() and self.current_token().type == TokenType.COMMA:
                        self.advance()
                        continue
                    break
                if self.current_token() and self.current_token().type == TokenType.GT:
                    self.advance()
                else:
                    self.debugger.log_warning(f"Expected '>' after generic types for {name}")
                return GenericType(name, args)
            return name

        val = token.value if getattr(token, 'value', None) is not None else token.type.name
        err = SyntaxError(f"Unknown type token: {token.type} (value={val}) at line {token.line}")
        err.lineno = token.line
        raise err

    def parse_import(self):
        self.expect(TokenType.IMPORT, "Expected 'import'")
        token = self.current_token()
        if not token: raise SyntaxError("Expected module name after import")
        if token.type in (TokenType.STRING, TokenType.NAME):
            module_name = token.value
            self.advance()
        else:
            self.debugger.log_warning("Expected name or string after import")
            module_name = token.value if getattr(token, 'value', None) is not None else ''
            self.advance()
        return ImportStmt(module_name, None)

    def parse_from_import(self):
        self.expect(TokenType.FROM, "Expected 'from'")
        token = self.current_token()
        if not token: raise SyntaxError("Expected module name after from")
        if token.type in (TokenType.STRING, TokenType.NAME):
            module = token.value
            self.advance()
        else:
            raise SyntaxError("Expected name or string after from")
            
        self.expect(TokenType.IMPORT, "Expected 'import' after module name")
        items = []
        while True:
            t = self.expect(TokenType.NAME, "Expected import name")
            items.append(t.value if t else None)
            if self.current_token() and self.current_token().type == TokenType.COMMA:
                self.advance()
                continue
            break
        return FromImportStmt(module, items, None)

    def parse_global_var(self):
        is_const = False
        if self.current_token() and self.current_token().type == TokenType.CONST:
            is_const = True
            self.advance()
        name = self.expect(TokenType.NAME, "Expected global variable name").value
        self.expect(TokenType.COLON, "Expected ':' after global variable name")
        var_type = self.parse_type()
        value = None
        if self.current_token() and self.current_token().type == TokenType.ASSIGN:
            self.advance()
            value = self.parse_expression()
        self.skip_newlines()
        return GlobalVariable(name, var_type, value, is_const)

    def parse(self) -> Program:
        functions: list[FunctionDef] = []
        structs: list[StructDef] = []
        imports: list[Any] = []
        global_vars: list[Any] = []

        self.skip_newlines()

        while self.current_token() and self.current_token().type in (TokenType.IMPORT, TokenType.FROM):
            try:
                if self.current_token().type == TokenType.IMPORT:
                    imports.append(self.parse_import())
                else:
                    imports.append(self.parse_from_import())
                self.skip_newlines()
            except SyntaxError as e:
                self.errors.append(e)
                self.synchronize()

        while self.current_token() and self.current_token().type != TokenType.EOF:
            try:
                if self.current_token().type == TokenType.NEWLINE:
                    self.skip_newlines()
                    continue

                if self.current_token().type == TokenType.COMPTIME:
                    _ = self.parse_comptime()
                    continue

                if self.current_token().type == TokenType.CONST:
                    gv = self.parse_global_var()
                    global_vars.append(gv)
                    continue

                decorators = None
                if self.current_token() and self.current_token().type == TokenType.AT:
                    decorators = self.parse_decorators()

                if self.current_token() and self.current_token().type == TokenType.STRUCT:
                    structs.append(self.parse_struct_def(decorators))
                    continue

                if self.current_token() and self.current_token().type == TokenType.ENUM:
                    enums = self.parse_enum_def()
                    if enums: structs.append(enums)
                    continue

                if self.current_token() and self.current_token().type in (TokenType.DEF, TokenType.EXTERN):
                    functions.append(self.parse_function(decorators))
                    continue

                stmt = self.parse_statement()
                if stmt:
                    if isinstance(stmt, Assign):
                        global_vars.append(GlobalVariable(stmt.target, getattr(stmt, 'var_type', None), stmt.value, False))
                else:
                    self.advance()

            except SyntaxError as e:
                self.errors.append(e)
                self.synchronize()

        if self.errors:
            raise ParsingError(self.errors)

        return Program(functions=functions, structs=structs, imports=imports, global_vars=global_vars)

    def parse_function(self, decorators: list[Decorator] | None = None) -> FunctionDef:
        token = self.current_token()
        start_line = token.line if token else 0
        
        is_extern = False
        if self.current_token() and self.current_token().type == TokenType.EXTERN:
            is_extern = True
            self.advance()
        self.expect(TokenType.DEF, "Expected 'def'")
        name = self.expect(TokenType.NAME, "Expected function name").value

        self.expect(TokenType.LPAREN, "Expected '('")
        params: list[tuple[str, Any]] = []
        is_vararg = False
        if self.current_token() and self.current_token().type != TokenType.RPAREN:
            while True:
                if self.current_token().type == TokenType.ELLIPSIS:
                    is_vararg = True
                    self.advance()
                    break
                pname = self.expect(TokenType.NAME, "Expected parameter name").value
                self.expect(TokenType.COLON, "Expected ':' after parameter name")
                ptype = self.parse_type()
                params.append((pname, ptype))
                if self.current_token() and self.current_token().type == TokenType.COMMA:
                    self.advance()
                    continue
                break
        self.expect(TokenType.RPAREN, "Expected ')'")

        return_type = None
        if self.current_token() and self.current_token().type == TokenType.ARROW:
            self.advance()
            return_type = self.parse_type()

        if is_extern:
            self.skip_newlines()
            return FunctionDef(name, params, return_type, [], is_extern=True, decorators=decorators, is_vararg=is_vararg, line=start_line)

        self.expect(TokenType.COLON, "Expected ':' after function signature")
        self.skip_newlines()
        body: list[Any] = []
        if self.current_token() and self.current_token().type == TokenType.INDENT:
            self.advance()
            while self.current_token() and self.current_token().type != TokenType.DEDENT:
                self.skip_newlines()
                if not self.current_token() or self.current_token().type == TokenType.DEDENT:
                    break
                stmt = self.parse_statement()
                if stmt:
                    body.append(stmt)
            if self.current_token() and self.current_token().type == TokenType.DEDENT:
                self.advance()
        else:
            stmt = self.parse_statement()
            if stmt: body.append(stmt)

        return FunctionDef(name, params, return_type, body, is_extern=False, decorators=decorators, is_vararg=is_vararg, line=start_line)

    def parse_struct_def(self, decorators: list[Decorator] | None = None) -> StructDef:
        token = self.current_token()
        start_line = token.line if token else 0
        self.expect(TokenType.STRUCT, "Expected 'struct'")
        name = self.expect(TokenType.NAME, "Expected struct name").value
        self.expect(TokenType.COLON, "Expected ':' after struct name")
        self.skip_newlines()
        if self.current_token() and self.current_token().type == TokenType.INDENT:
            self.advance()
        else:
            raise SyntaxError("Expected indent after struct ':'")
        fields: list[tuple[str, Any]] = []
        while self.current_token() and self.current_token().type != TokenType.DEDENT:
            self.skip_newlines()
            if not self.current_token() or self.current_token().type == TokenType.DEDENT:
                break
            fname = self.expect(TokenType.NAME, "Expected field name").value
            self.expect(TokenType.COLON, "Expected ':' after field name")
            ftype = self.parse_type()
            fields.append((fname, ftype))
        if self.current_token() and self.current_token().type == TokenType.DEDENT:
            self.advance()
        return StructDef(name, fields, decorators=decorators, line=start_line)

    def parse_enum_def(self) -> EnumDef:
        token = self.current_token()
        start_line = token.line if token else 0
        self.expect(TokenType.ENUM, "Expected 'enum'")
        name = self.expect(TokenType.NAME, "Expected enum name").value
        self.expect(TokenType.COLON, "Expected ':' after enum name")
        self.skip_newlines()
        if self.current_token() and self.current_token().type == TokenType.INDENT:
            self.advance()
        else:
            raise SyntaxError("Expected indent after enum ':'")
        members: list[tuple[str, Any | None]] = []
        while self.current_token() and self.current_token().type != TokenType.DEDENT:
            self.skip_newlines()
            if not self.current_token() or self.current_token().type == TokenType.DEDENT:
                break
            mname = self.expect(TokenType.NAME, "Expected enum member name").value
            mval = None
            if self.current_token() and self.current_token().type == TokenType.ASSIGN:
                self.advance()
                mval = self.parse_expression()
            members.append((mname, mval))
        if self.current_token() and self.current_token().type == TokenType.DEDENT:
            self.advance()
        return EnumDef(name, members, line=start_line)

    def parse_comptime(self) -> ComptimeBlock:
        self.expect(TokenType.COMPTIME, "Expected 'comptime'")
        self.skip_newlines()
        code_parts: list[str] = []
        if self.current_token() and self.current_token().type == TokenType.INDENT:
            self.advance()
            while self.current_token() and self.current_token().type != TokenType.DEDENT:
                t = self.current_token()
                if t.type == TokenType.NEWLINE:
                    code_parts.append('\n')
                else:
                    code_parts.append(t.value or '')
                self.advance()
            if self.current_token() and self.current_token().type == TokenType.DEDENT:
                self.advance()
        return ComptimeBlock(''.join(code_parts))

    def parse_statement(self):
        token = self.current_token()
        if not token: return None
        start_line = token.line
        
        try:
            stmt = self._parse_statement_impl()
            if stmt and hasattr(stmt, 'line') and getattr(stmt, 'line', 0) == 0:
                stmt.line = start_line
            return stmt
        except SyntaxError as e:
            self.errors.append(e)
            self.synchronize()
            return None

    def _parse_statement_impl(self):
        token = self.current_token()
        if token.type == TokenType.ASM:
            self.advance()
            self.expect(TokenType.LPAREN, "Expected '(' after asm")
            s = self.expect(TokenType.STRING, "Expected asm string").value
            self.expect(TokenType.RPAREN, "Expected ')'")
            return InlineAsm(s)

        if token.type == TokenType.RETURN: return self.parse_return()
        if token.type == TokenType.DEFER: return self.parse_defer_stmt()
        if token.type == TokenType.ENDOFCODE:
            self.advance()
            return Return(Literal(0, 'int'), is_endofcode=True)
        if token.type == TokenType.IF: return self.parse_if_stmt()
        if token.type == TokenType.WHILE: return self.parse_while_stmt()
        if token.type == TokenType.FOR: return self.parse_for_stmt()
        if token.type == TokenType.MATCH: return self.parse_match_stmt()
        
        if token.type == TokenType.BREAK:
            self.advance()
            return BreakStmt()
        if token.type == TokenType.CONTINUE:
            self.advance()
            return ContinueStmt()

        if token.type == TokenType.LET:
            self.advance()
            name = self.expect(TokenType.NAME, "Expected variable name after let").value
            self.expect(TokenType.ASSIGN, "Expected '=' in let")
            val = self.parse_expression()
            return Assign(name, val)

        expr = self.parse_expression()
        
        if isinstance(expr, Variable) and self.current_token() and self.current_token().type == TokenType.COLON:
            self.advance() 
            t = self.parse_type()
            val = Literal(0, 'int')
            if self.current_token() and self.current_token().type == TokenType.ASSIGN:
                self.advance()
                val = self.parse_expression()
            return Assign(expr.name, val, t)

        if self.current_token() and self.current_token().type in (TokenType.ASSIGN, TokenType.PLUS_ASSIGN, TokenType.MINUS_ASSIGN):
            op = self.current_token().type
            self.advance()
            val = self.parse_expression()
            
            if op == TokenType.PLUS_ASSIGN:
                val = BinaryOp('+', expr, val)
            elif op == TokenType.MINUS_ASSIGN:
                val = BinaryOp('-', expr, val)
                
            if isinstance(expr, Variable):
                return Assign(expr.name, val)
            return Assign(expr, val)
            
        return expr

    def parse_defer_stmt(self) -> DeferStmt:
        token = self.expect(TokenType.DEFER, "Expected 'defer'")
        if self.current_token() and self.current_token().type == TokenType.COLON:
            self.advance()
            self.skip_newlines()
            self.expect(TokenType.INDENT, "Expected indent for defer block")
            body: list[Any] = []
            while self.current_token() and self.current_token().type != TokenType.DEDENT:
                s = self.parse_statement()
                if s: body.append(s)
                self.skip_newlines()
            self.expect(TokenType.DEDENT, "Expected dedent after defer block")
            return DeferStmt(body, line=token.line)
        else:
            s = self.parse_statement()
            return DeferStmt([s] if s else [], line=token.line)

    def parse_return(self) -> Return:
        self.expect(TokenType.RETURN, "Expected 'return'")
        if self.current_token() and self.current_token().type not in (TokenType.NEWLINE, TokenType.DEDENT, TokenType.EOF):
            v = self.parse_expression()
        else:
            v = None
        return Return(v)

    def parse_if_stmt(self) -> IfStmt:
        self.expect(TokenType.IF, "Expected 'if'")
        cond = self.parse_expression()
        self.expect(TokenType.COLON, "Expected ':' after if condition")
        self.skip_newlines()
        self.expect(TokenType.INDENT, "Expected indent for if body")
        then: list[Any] = []
        while self.current_token() and self.current_token().type != TokenType.DEDENT:
            s = self.parse_statement()
            if s: then.append(s)
            self.skip_newlines()
        self.expect(TokenType.DEDENT, "Expected dedent after if body")
        
        else_body = None
        if self.current_token() and self.current_token().type == TokenType.ELSE:
            self.advance()
            self.expect(TokenType.COLON, "Expected ':' after else")
            self.skip_newlines()
            self.expect(TokenType.INDENT, "Expected indent for else body")
            else_body = []
            while self.current_token() and self.current_token().type != TokenType.DEDENT:
                s = self.parse_statement()
                if s: else_body.append(s)
                self.skip_newlines()
            self.expect(TokenType.DEDENT, "Expected dedent after else body")
        return IfStmt(cond, then, else_body)

    def parse_while_stmt(self) -> WhileLoop:
        self.expect(TokenType.WHILE, "Expected 'while'")
        cond = self.parse_expression()
        self.expect(TokenType.COLON, "Expected ':' after while")
        self.skip_newlines()
        self.expect(TokenType.INDENT, "Expected indent for while body")
        body: list[Any] = []
        while self.current_token() and self.current_token().type != TokenType.DEDENT:
            s = self.parse_statement()
            if s: body.append(s)
            self.skip_newlines()
        self.expect(TokenType.DEDENT, "Expected dedent after while body")
        return WhileLoop(cond, body)

    def parse_for_stmt(self) -> ForLoop:
        self.expect(TokenType.FOR, "Expected 'for'")
        if self.current_token() and self.current_token().type == TokenType.LPAREN:
            self.advance()
            init = None
            if self.current_token() and self.current_token().type != TokenType.SEMICOLON:
                if self.current_token().type == TokenType.LET:
                    init = self.parse_statement()
                else:
                    init = self.parse_statement()
            self.expect(TokenType.SEMICOLON, "Expected ';' in for header")
            
            cond = None
            if self.current_token() and self.current_token().type != TokenType.SEMICOLON:
                cond = self.parse_expression()
            self.expect(TokenType.SEMICOLON, "Expected second ';' in for header")
            
            post = None
            if self.current_token() and self.current_token().type != TokenType.RPAREN:
                post = self.parse_statement()
            self.expect(TokenType.RPAREN, "Expected ')' after for header")
            self.expect(TokenType.COLON, "Expected ':' after for header")
            self.skip_newlines()
            self.expect(TokenType.INDENT, "Expected indent for for body")
            body: list[Any] = []
            while self.current_token() and self.current_token().type != TokenType.DEDENT:
                s = self.parse_statement()
                if s: body.append(s)
                self.skip_newlines()
            self.expect(TokenType.DEDENT, "Expected dedent after for body")
            return ForLoop(None, None, init, cond, post, body)

        var_name = None
        if self.current_token() and self.current_token().type == TokenType.NAME:
            var_name = self.current_token().value
            self.advance()
        self.expect(TokenType.IN, "Expected 'in' in for statement")
        
        if self.current_token() and self.peek_token() and self.peek_token().type == TokenType.RANGE:
            start_expr = self.parse_atom()
            self.advance() 
            end_expr = self.parse_expression()
            iter_expr = Call(Variable('range'), [start_expr, end_expr])
        else:
            iter_expr = self.parse_expression()
            
        self.expect(TokenType.COLON, "Expected ':' after for header")
        self.skip_newlines()
        self.expect(TokenType.INDENT, "Expected indent for for body")
        body: list[Any] = []
        while self.current_token() and self.current_token().type != TokenType.DEDENT:
            s = self.parse_statement()
            if s: body.append(s)
            self.skip_newlines()
        self.expect(TokenType.DEDENT, "Expected dedent after for body")
        return ForLoop(var_name, iter_expr, None, None, None, body)

    def parse_match_stmt(self) -> MatchStmt:
        self.expect(TokenType.MATCH, "Expected 'match'")
        expr = self.parse_expression()
        self.expect(TokenType.COLON, "Expected ':' after match expression")
        self.skip_newlines()
        self.expect(TokenType.INDENT, "Expected indent for match body")
        cases: list[Case] = []
        while self.current_token() and self.current_token().type != TokenType.DEDENT:
            if self.current_token().type == TokenType.CASE:
                self.advance()
                vals: list[Any] = []
                while True:
                    vals.append(self.parse_expression())
                    if self.current_token() and self.current_token().type == TokenType.COMMA:
                        self.advance()
                        continue
                    break
                self.expect(TokenType.COLON, "Expected ':' after case values")
                self.skip_newlines()
                self.expect(TokenType.INDENT, "Expected indent for case body")
                body: list[Any] = []
                while self.current_token() and self.current_token().type != TokenType.DEDENT:
                    s = self.parse_statement()
                    if s: body.append(s)
                    self.skip_newlines()
                self.expect(TokenType.DEDENT, "Expected dedent after case body")
                cases.append(Case(vals, body))
            elif self.current_token().type == TokenType.DEFAULT:
                self.advance()
                self.expect(TokenType.COLON, "Expected ':' after default")
                self.skip_newlines()
                self.expect(TokenType.INDENT, "Expected indent for default body")
                body: list[Any] = []
                while self.current_token() and self.current_token().type != TokenType.DEDENT:
                    s = self.parse_statement()
                    if s: body.append(s)
                    self.skip_newlines()
                self.expect(TokenType.DEDENT, "Expected dedent after default body")
                cases.append(Case(None, body))
            else:
                self.advance()
        self.expect(TokenType.DEDENT, "Expected dedent after match body")
        return MatchStmt(expr, cases)

    def parse_expression(self):
        token = self.current_token()
        if not token: return None
        start_line = token.line

        expr = self._parse_expression_impl()
        if expr and hasattr(expr, 'line') and getattr(expr, 'line', 0) == 0:
            expr.line = start_line
        return expr

    def _parse_expression_impl(self):
        expr = self.parse_logical_or()
        
        if self.current_token() and self.current_token().type == TokenType.WALRUS:
            self.advance()
            val = self.parse_expression()
            return WalrusExpr(expr, val)
            
        return expr

    def parse_logical_or(self):
        left = self.parse_logical_and()
        while self.current_token() and self.current_token().type == TokenType.OR:
            self.advance()
            right = self.parse_logical_and()
            left = LogicalOp('or', left, right)
        return left

    def parse_logical_and(self):
        left = self.parse_logical_not()
        while self.current_token() and self.current_token().type == TokenType.AND:
            self.advance()
            right = self.parse_logical_not()
            left = LogicalOp('and', left, right)
        return left

    def parse_logical_not(self):
        if self.current_token() and self.current_token().type == TokenType.NOT:
            self.advance()
            expr = self.parse_logical_not()
            return LogicalOp('not', expr)
        return self.parse_bitwise_or()

    def parse_bitwise_or(self):
        left = self.parse_bitwise_xor()
        while self.current_token() and self.current_token().type == TokenType.PIPE:
            self.advance()
            right = self.parse_bitwise_xor()
            left = BinaryOp('|', left, right)
        return left

    def parse_bitwise_xor(self):
        left = self.parse_bitwise_and()
        while self.current_token() and self.current_token().type == TokenType.CARET:
            self.advance()
            right = self.parse_bitwise_and()
            left = BinaryOp('^', left, right)
        return left

    def parse_bitwise_and(self):
        left = self.parse_comparison()
        while self.current_token() and self.current_token().type == TokenType.AMP:
            self.advance()
            right = self.parse_comparison()
            left = BinaryOp('&', left, right)
        return left

    def parse_comparison(self):
        left = self.parse_additive()
        comps = (TokenType.EQ, TokenType.NE, TokenType.LT, TokenType.GT, TokenType.LE, TokenType.GE)
        while self.current_token() and self.current_token().type in comps:
            t = self.advance()
            op_map = {
                TokenType.EQ: '==', TokenType.NE: '!=', TokenType.LT: '<', TokenType.GT: '>', TokenType.LE: '<=', TokenType.GE: '>='
            }
            right = self.parse_additive()
            left = Compare(op_map[t.type], left, right)
        return left

    def parse_additive(self):
        left = self.parse_multiplicative()
        while self.current_token() and self.current_token().type in (TokenType.PLUS, TokenType.MINUS):
            t = self.advance()
            right = self.parse_multiplicative()
            left = BinaryOp(t.value, left, right)
        return left

    def parse_multiplicative(self):
        left = self.parse_power()
        while self.current_token() and self.current_token().type in (TokenType.MULTIPLY, TokenType.DIVIDE, TokenType.MODULO):
            t = self.advance()
            right = self.parse_power()
            left = BinaryOp(t.value, left, right)
        return left

    def parse_power(self):
        left = self.parse_unary()
        if self.current_token() and self.current_token().type == TokenType.POW:
            t = self.advance()
            right = self.parse_power() 
            left = BinaryOp(t.value, left, right)
        return left

    def parse_unary(self):
        token = self.current_token()
        if token and token.type == TokenType.MULTIPLY:
            self.advance()
            expr = self.parse_unary()
            return Dereference(expr)
        if token and token.type == TokenType.AMP:
            self.advance()
            var = self.parse_unary()
            return AddressOf(var)
        if token and token.type == TokenType.MINUS:
            self.advance()
            expr = self.parse_unary()
            return BinaryOp('-', Literal(0, 'int'), expr)
        if token and token.type == TokenType.SIZEOF:
            self.advance()
            if self.current_token() and self.current_token().type == TokenType.LPAREN:
                self.advance()
                t = self.parse_type()
                self.expect(TokenType.RPAREN, "Expected ')' after sizeof type")
                return SizeOf(t)
        return self.parse_atom()

    def parse_atom(self):
        token = self.current_token()
        if not token:
            raise SyntaxError("Unexpected EOF in expression")

        if token.type == TokenType.STRING:
            self.advance()
            expr: Any = Literal(token.value, 'str', line=token.line)

        elif token.type == TokenType.NUMBER:
            self.advance()
            if '.' in token.value:
                expr = Literal(float(token.value), 'float', line=token.line)
            else:
                expr = Literal(int(token.value, 0), 'int', line=token.line)

        elif token.type == TokenType.NAME:
            name = token.value
            self.advance()

            type_args = None
            if self.current_token() and self.current_token().type == TokenType.LT:
                saved_pos = self.pos
                try:
                    self.advance()
                    args: list[Any] = []
                    while True:
                        args.append(self.parse_type())
                        if self.current_token() and self.current_token().type == TokenType.COMMA:
                            self.advance()
                            continue
                        break
                    if self.current_token() and self.current_token().type == TokenType.GT:
                        self.advance()
                        type_args = args
                    else:
                        self.pos = saved_pos
                except SyntaxError:
                    self.pos = saved_pos

            if self.current_token() and self.current_token().type == TokenType.LPAREN:
                expr = self.parse_call(Variable(name, line=token.line), type_args)
                expr.line = token.line
            else:
                expr = Variable(name, line=token.line)

        elif token.type == TokenType.LPAREN:
            self.advance()
            expr = self.parse_expression()
            self.expect(TokenType.RPAREN, "Expected ')'")

        elif token.type == TokenType.LBRACKET or token.type == TokenType.LBRACE:
            is_struct_init = (token.type == TokenType.LBRACE)
            end_tok = TokenType.RBRACKET if token.type == TokenType.LBRACKET else TokenType.RBRACE
            self.advance()
            elems: list[Any] = []
            if not (self.current_token() and self.current_token().type == end_tok):
                while True:
                    elems.append(self.parse_expression())
                    if self.current_token() and self.current_token().type == TokenType.COMMA:
                        self.advance(); continue
                    break
            if end_tok == TokenType.RBRACKET:
                self.expect(TokenType.RBRACKET, "Expected ']' in array literal")
            else:
                self.expect(TokenType.RBRACE, "Expected '}' in struct initializer")

            arr = ArrayLiteral(elems, line=token.line)
            if is_struct_init:
                setattr(arr, 'is_struct_init', True)
            expr = arr

        else:
            err = SyntaxError(f"Unexpected token {token.type} in atom at line {token.line}")
            err.lineno = token.line
            raise err

        while self.current_token() and self.current_token().type in (TokenType.DOT, TokenType.LBRACKET, TokenType.AS, TokenType.LPAREN):
            if self.current_token().type == TokenType.DOT:
                self.advance()
                fld = self.expect(TokenType.NAME, "Expected field name").value
                expr = FieldAccess(expr, fld, line=expr.line)

            elif self.current_token().type == TokenType.LBRACKET:
                self.advance()
                idx = self.parse_expression()
                self.expect(TokenType.RBRACKET, "Expected ']' in index")
                expr = ArrayAccess(expr, idx, line=expr.line)

            elif self.current_token().type == TokenType.AS:
                self.advance()
                tgt = self.parse_type()
                expr = CastExpr(expr, tgt, line=expr.line)
                
            elif self.current_token().type == TokenType.LPAREN:
                expr = self.parse_call(expr)

        return expr

    def parse_call(self, func_name: Any, type_args: list[Any] | None = None) -> Call:
        self.expect(TokenType.LPAREN, "Expected '(' after call name")
        args: list[Any] = []
        if self.current_token() and self.current_token().type != TokenType.RPAREN:
            while True:
                args.append(self.parse_expression())
                if self.current_token() and self.current_token().type == TokenType.COMMA:
                    self.advance(); continue
                break
        self.expect(TokenType.RPAREN, "Expected ')' after call arguments")
        return Call(func_name, args, type_args)

def parse(tokens: List[Token]) -> Program:
    return Parser(tokens).parse()