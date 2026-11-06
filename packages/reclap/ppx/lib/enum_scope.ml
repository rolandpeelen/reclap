(* The @clap.valueEnum types that a structure can see, with their skipped
   constructors, so that a [default:] naming a skipped value is a compile
   error rather than a default that formats as [""].

   Only types declared in the same file are known: the PPX sees one file and
   no types. A type of the enclosing structures is visible unqualified, a type
   of a nested module as [Module.type]. Shadowing is not modelled. *)

open Parsetree0

type entry = {
  module_path : string list;
  type_name : string;
  skipped : string list;  (** constructors with @value(skip) *)
}

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
  match declaration.ptype_kind with
  | Ptype_variant constructors when is_value_enum declaration ->
      Some
        {
          module_path = [];
          type_name = declaration.ptype_name.txt;
          skipped =
            List.filter_map
              (fun (constructor : constructor_declaration) ->
                if is_skipped constructor then Some constructor.pcd_name.txt else None)
              constructors;
        }
  | Ptype_variant _ | Ptype_abstract | Ptype_record _ | Ptype_open -> None

let rec collect (items : structure) =
  List.concat_map
    (fun (item : structure_item) ->
      match item.pstr_desc with
      | Pstr_type (_, declarations) -> List.filter_map declaration_entry declarations
      | Pstr_module binding -> collect_binding binding
      | Pstr_recmodule bindings -> List.concat_map collect_binding bindings
      | Pstr_eval _ | Pstr_value _ | Pstr_primitive _ | Pstr_typext _ | Pstr_exception _
      | Pstr_modtype _ | Pstr_open _ | Pstr_class _ | Pstr_class_type _ | Pstr_include _
      | Pstr_attribute _ | Pstr_extension _ ->
          [])
    items

and collect_binding (binding : module_binding) =
  List.map
    (fun entry -> { entry with module_path = binding.pmb_name.txt :: entry.module_path })
    (collect_module binding.pmb_expr)

and collect_module (expression : module_expr) =
  match expression.pmod_desc with
  | Pmod_structure items -> collect items
  | Pmod_constraint (inner, _) -> collect_module inner
  | Pmod_ident _ | Pmod_apply _ | Pmod_functor _ | Pmod_unpack _ | Pmod_extension _ -> []

(* The scope inside a structure: its own types, then those of the enclosing
   structures. *)
let enter (scope : t) items : t = collect items @ scope

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
