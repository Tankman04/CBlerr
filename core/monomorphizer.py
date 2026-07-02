import pickle
from typing import Any
from core.flux_ast import Program, FunctionDef, StructDef, Call

def _fast_deepcopy(obj):
    return pickle.loads(pickle.dumps(obj, -1))

def stringify_type(t: Any) -> str:
    if t is None: return "void"
    if isinstance(t, str):
        return t.replace('*', 'ptr_').replace('<', '_').replace('>', '_').replace(',', '_').replace(' ', '')
    
    cname = t.__class__.__name__
    if cname == 'GenericType':
        args = '_'.join(stringify_type(a) for a in t.args)
        return f"{t.name}_{args}__"
    if cname == 'PointerType':
        return f"ptr_{stringify_type(t.base_type)}"
    return str(t).replace('*', 'ptr_').replace('<', '_').replace('>', '_').replace(',', '_').replace(' ', '')

def type_to_str(t: Any) -> str:
    if t is None: return "void"
    if isinstance(t, str): return t
    
    cname = t.__class__.__name__
    if cname == 'GenericType':
        args = ','.join(type_to_str(a) for a in t.args)
        return f"{t.name}<{args}>"
    if cname == 'PointerType':
        return f"*{type_to_str(t.base_type)}"
    return str(t)

def collect_placeholders_from_type(t: Any, acc: list[str]):
    if isinstance(t, str):
        base = t.replace('*', '')
        if base and len(base) == 1 and base.isupper() and base not in acc: 
            acc.append(base)
    else:
        cname = t.__class__.__name__
        if cname == 'GenericType':
            if t.name and len(t.name) == 1 and t.name.isupper() and t.name not in acc: 
                acc.append(t.name)
            for a in t.args: collect_placeholders_from_type(a, acc)
        elif cname == 'PointerType':
            collect_placeholders_from_type(t.base_type, acc)

def collect_placeholders_from_func(f: FunctionDef) -> list[str]:
    acc: list[str] = []
    for _, ptype in f.params: collect_placeholders_from_type(ptype, acc)
    if f.return_type is not None: collect_placeholders_from_type(f.return_type, acc)
    return acc

def resolve_type(t: Any, mapping: dict) -> Any:
    if t is None: return None
    if isinstance(t, str):
        stars, base = "", t
        while base.startswith('*'):
            stars += "*"
            base = base[1:]
        if base in mapping:
            mapped = mapping[base]
            if isinstance(mapped, str): return stars + mapped
            if stars: return stars + type_to_str(mapped)
            return mapped
        return t
    
    cname = t.__class__.__name__
    if cname == 'GenericType':
        from core.flux_ast import GenericType
        return GenericType(t.name, [resolve_type(a, mapping) for a in t.args])
    if cname == 'PointerType':
        from core.flux_ast import PointerType
        return PointerType(resolve_type(t.base_type, mapping))
    return t

def replace_types_in_node(node: Any, mapping: dict) -> None:
    if node is None: return
    if isinstance(node, list):
        for x in node: replace_types_in_node(x, mapping)
        return

    if hasattr(node, '__dict__'):
        for k, v in vars(node).items():
            if k in ('var_type', 'return_type', 'target_type', 'array_type') and v is not None:
                setattr(node, k, resolve_type(v, mapping))
            elif k == 'type_args' and v is not None:
                setattr(node, k, [resolve_type(a, mapping) for a in v])
            else:
                replace_types_in_node(v, mapping)

def monomorphize(program: Program) -> Program:
    prog = _fast_deepcopy(program)

    func_map = {f.name: f for f in prog.functions}
    struct_map = {s.name: s for s in prog.structs}

    def clone_and_instantiate_function(orig_name: str, type_args: list[Any]) -> str | None:
        orig = func_map.get(orig_name)
        if not orig: return None

        placeholders = collect_placeholders_from_func(orig)
        mapping = {ph: type_to_str(type_args[i]) for i, ph in enumerate(placeholders) if i < len(type_args)}

        mangled_suffix = '__'.join(stringify_type(t) for t in type_args)
        mangled_name = f"{orig.name}__{mangled_suffix}"
        
        if mangled_name in func_map: return mangled_name

        new_def = _fast_deepcopy(orig)
        new_def.name = mangled_name
        new_def.params = [(pname, resolve_type(ptype, mapping)) for pname, ptype in new_def.params]
        new_def.return_type = resolve_type(new_def.return_type, mapping)

        for stmt in new_def.body: replace_types_in_node(stmt, mapping)
        
        prog.functions.append(new_def)
        func_map[mangled_name] = new_def 
        return mangled_name

    def clone_and_instantiate_struct(orig_name: str, type_args: list[Any]) -> str | None:
        orig = struct_map.get(orig_name)
        if not orig: return None

        placeholders: list[str] = []
        for _, ftype in (orig.fields if isinstance(orig.fields, list) else orig.fields.items()):
            collect_placeholders_from_type(ftype, placeholders)

        mapping = {ph: type_to_str(type_args[i]) for i, ph in enumerate(placeholders) if i < len(type_args)}
        mangled_suffix = '__'.join(stringify_type(t) for t in type_args)
        mangled_name = f"{orig.name}__{mangled_suffix}"
        
        if mangled_name in struct_map: return mangled_name

        new_def = _fast_deepcopy(orig)
        new_def.name = mangled_name
        new_def.fields = [(fname, resolve_type(ftype, mapping)) for fname, ftype in new_def.fields]
        
        prog.structs.append(new_def)
        struct_map[mangled_name] = new_def
        return mangled_name

    def visit(node: Any):
        if node is None: return None
        if isinstance(node, list):
            for i, x in enumerate(node): node[i] = visit(x)
            return node

        cname = node.__class__.__name__

        if cname == 'Call':
            node.args = [visit(a) for a in node.args]
            if node.type_args and isinstance(node.func_name, str):
                mangled = clone_and_instantiate_function(node.func_name, node.type_args)
                if mangled: node.func_name = mangled
                node.type_args = None
            return node

        if cname == 'GenericType':
            mangled = clone_and_instantiate_struct(node.name, node.args)
            return mangled if mangled else type_to_str(node)

        if hasattr(node, '__dict__'):
            for k, v in vars(node).items():
                if isinstance(v, list):
                    for i, x in enumerate(v): v[i] = visit(x)
                else:
                    setattr(node, k, visit(v))
        return node

    for f in list(prog.functions): f.body = [visit(s) for s in f.body]
    prog.global_vars = [visit(g) for g in prog.global_vars]
    prog.structs = [visit(s) for s in prog.structs]

    return prog