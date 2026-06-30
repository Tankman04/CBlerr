
from dataclasses import dataclass, field
from typing import Any

@dataclass
class Literal:
    value: Any
    type: str
    line: int = field(default=0)

@dataclass
class StringLiteral:
    value: str
    length: int
    line: int = field(default=0)

@dataclass
class Variable:
    name: str
    line: int = field(default=0)

@dataclass
class BinaryOp:
    op: str
    left: Any
    right: Any
    line: int = field(default=0)

@dataclass
class Compare:
    op: str
    left: Any
    right: Any
    line: int = field(default=0)

@dataclass
class LogicalOp:
    op: str
    left: Any
    right: Any | None = None
    line: int = field(default=0)

@dataclass
class WalrusExpr:
    target: Any
    value: Any
    line: int = field(default=0)

@dataclass
class Assign:
    target: str
    value: Any
    var_type: str | None = None
    line: int = field(default=0)

@dataclass
class DeferStmt:
    body: list[Any]
    line: int = field(default=0)

@dataclass
class Return:
    value: Any | None = None
    is_endofcode: bool = False
    line: int = field(default=0)

@dataclass
class IfStmt:
    condition: Any
    then_body: list[Any]
    else_body: list[Any] | None = None
    line: int = field(default=0)

@dataclass
class WhileLoop:
    condition: Any
    body: list[Any]
    line: int = field(default=0)

@dataclass
class BreakStmt:
    line: int = field(default=0)

@dataclass
class ContinueStmt:
    line: int = field(default=0)

@dataclass
class Call:
    func_name: Any
    args: list[Any]
    type_args: list[Any] | None = None
    line: int = field(default=0)

@dataclass
class FieldAccess:
    obj: Any
    field: str
    line: int = field(default=0)

@dataclass
class ArrayAccess:
    arr: Any
    index: Any
    line: int = field(default=0)

@dataclass
class ArrayLiteral:
    elements: list[Any]
    array_type: str | None = None
    line: int = field(default=0)

@dataclass
class PointerType:
    base_type: str
    line: int = field(default=0)

@dataclass
class Dereference:
    ptr: Any
    index: Any | None = None
    line: int = field(default=0)

@dataclass
class InlineAsm:
    code: str
    outputs: str = ""
    inputs: str = ""
    clobbers: str = ""
    volatile: bool = True
    line: int = field(default=0)

@dataclass
class CastExpr:
    expr: Any
    target_type: Any
    line: int = field(default=0)

@dataclass
class Decorator:
    name: str
    args: list[str] | None = None
    line: int = field(default=0)

@dataclass
class ComptimeBlock:
    code: str
    line: int = field(default=0)

@dataclass
class Case:
    values: list[Any] | None
    body: list[Any]
    line: int = field(default=0)

@dataclass
class MatchStmt:
    expr: Any
    cases: list[Case]
    line: int = field(default=0)

@dataclass
class ForLoop:
    iter_var: str | None
    iter_expr: Any | None
    init: Any | None
    condition: Any | None
    post: Any | None
    body: list[Any]
    line: int = field(default=0)

@dataclass
class EnumDef:
    name: str
    members: list[tuple[str, Any | None]]
    line: int = field(default=0)

@dataclass
class AddressOf:
    expr: Any
    line: int = field(default=0)

@dataclass
class SizeOf:
    target: Any
    line: int = field(default=0)

@dataclass
class GenericType:
    name: str
    args: list[Any]
    line: int = field(default=0)

@dataclass
class GlobalVariable:
    name: str
    var_type: str
    value: Any | None = None
    is_const: bool = False
    line: int = field(default=0)

@dataclass
class FunctionDef:
    name: str
    params: list[tuple[str, Any]]
    return_type: Any | None
    body: list[Any]
    is_extern: bool = False
    decorators: list[Decorator] | None = None
    is_vararg: bool = False
    line: int = field(default=0)

@dataclass
class StructDef:
    name: str
    fields: list[tuple[str, Any]]
    decorators: list[Decorator] | None = None
    line: int = field(default=0)

@dataclass
class ImportStmt:
    module_name: str
    items: list[str] | None = None
    line: int = field(default=0)

@dataclass
class FromImportStmt:
    module_name: str
    items: list[str]
    aliases: dict | None = None
    line: int = field(default=0)

@dataclass
class Program:
    functions: list[FunctionDef] = field(default_factory=list)
    structs: list[StructDef] = field(default_factory=list)
    imports: list[Any] = field(default_factory=list)
    global_vars: list[GlobalVariable] = field(default_factory=list)