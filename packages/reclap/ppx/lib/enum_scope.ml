(* The types that a type declaration can see, with the skipped constructors of
   the @clap.valueEnum ones, so that a [default:] naming a skipped value is a
   compile error rather than a default that formats as [""].

   Only types declared in the same file are known: the PPX sees one file and
   no types. The scope follows the source: a declaration sees the types
   declared before it (and those of its own group), the types of the
   enclosing structures, and those of earlier nested modules as
   [Module.type]. Every type is recorded, so a plain type shadows a value enum
   of the same name. [open] and [include] are not modelled: a type reached
   through them is unknown, and an unknown type is never reported. *)

open Parsetree0

type entry = {
  module_path : string list;
  type_name : string;
  skipped : string list;  (** constructors with @value(skip); [] for other types *)
}

(* Newest first, so the first match is the visible declaration. *)
type t = entry list

let empty : t = []

let is_value_enum (declaration : type_declaration) =
  List.exists
    (fun attribute -> Payload.attribute_name attribute = "clap.valueEnum")
    declaration.ptype_attributes

(* Errors in the attribute are reported when the type itself is analysed. *)
let is_skipped (constructor : constructor_declaration) =
  let errors = Diagnostic.collector () in
  List.exists
    (fun attribute ->
      match Payload.find "skip" (Payload.entries errors attribute) with
      | None -> false
      | Some entry -> Payload.flag errors entry)
    (Payload.find_all "value" constructor.pcd_attributes)

let declaration_entry (declaration : type_declaration) =
  let skipped =
    match declaration.ptype_kind with
    | Ptype_variant constructors when is_value_enum declaration ->
        List.filter_map
          (fun (constructor : constructor_declaration) ->
            if is_skipped constructor then Some constructor.pcd_name.txt else None)
          constructors
    | Ptype_variant _ | Ptype_abstract | Ptype_record _ | Ptype_open -> []
  in
  { module_path = []; type_name = declaration.ptype_name.txt; skipped }

(* The scope with a type declaration group added. *)
let add_types (scope : t) declarations : t =
  List.rev_append (List.map declaration_entry declarations) scope

(* Every type of a structure, newest first, as seen from after it. *)
let rec contents (items : structure) : t =
  List.fold_left
    (fun scope (item : structure_item) ->
      match item.pstr_desc with
      | Pstr_type (_, declarations) -> add_types scope declarations
      | Pstr_module binding -> add_module scope binding
      | Pstr_recmodule bindings -> List.fold_left add_module scope bindings
      | Pstr_eval _ | Pstr_value _ | Pstr_primitive _ | Pstr_typext _ | Pstr_exception _
      | Pstr_modtype _ | Pstr_open _ | Pstr_class _ | Pstr_class_type _ | Pstr_include _
      | Pstr_attribute _ | Pstr_extension _ ->
          scope)
    empty items

and module_contents (expression : module_expr) =
  match expression.pmod_desc with
  | Pmod_structure items -> contents items
  | Pmod_constraint (inner, _) -> module_contents inner
  | Pmod_ident _ | Pmod_apply _ | Pmod_functor _ | Pmod_unpack _ | Pmod_extension _ -> []

(* The scope after a module binding: its types, qualified by its name. *)
and add_module (scope : t) (binding : module_binding) : t =
  List.map
    (fun entry -> { entry with module_path = binding.pmb_name.txt :: entry.module_path })
    (module_contents binding.pmb_expr)
  @ scope

let rec flatten : Longident.t -> string list option = function
  | Lident name -> Some [ name ]
  | Ldot (path, name) -> Option.map (fun path -> path @ [ name ]) (flatten path)
  | Lapply _ -> None

(* The skipped constructors of a value type, or [] when the type is unknown. *)
let skipped (scope : t) (target : Spec.type_ref) =
  let path =
    match target.module_path with None -> Some [] | Some path -> flatten path
  in
  match path with
  | None -> []
  | Some path -> (
      match
        List.find_opt
          (fun entry -> entry.module_path = path && entry.type_name = target.type_name)
          scope
      with
      | Some entry -> entry.skipped
      | None -> [])
