(* The reclap PPX: derives command line parsers from [@clap.*] type
   declarations. [rewrite] walks structures and signatures, including nested
   modules, and hands every type declaration group to [Derive]. *)

module Parsetree0 = Parsetree0
module Ast_io = Ast_io
module Casing = Casing
module Doc_comment = Doc_comment
module Naming = Naming
open Parsetree0

(* Walks the items in source order, so each type declaration sees the types
   declared before it and those of its own group. *)
let rec map_structure ~module_name ~enums items =
  let _, mapped =
    List.fold_left
      (fun (enums, mapped) (item : structure_item) ->
        (* The scope of the item, and the scope after it. *)
        let enums, after =
          match item.pstr_desc with
          | Pstr_type (_, declarations) ->
              let enums = Enum_scope.add_types enums declarations in
              (enums, enums)
          | Pstr_module binding -> (enums, Enum_scope.add_module enums binding)
          | Pstr_recmodule bindings ->
              (enums, List.fold_left Enum_scope.add_module enums bindings)
          | Pstr_eval _ | Pstr_value _ | Pstr_primitive _ | Pstr_typext _ | Pstr_exception _
          | Pstr_modtype _ | Pstr_open _ | Pstr_class _ | Pstr_class_type _ | Pstr_include _
          | Pstr_attribute _ | Pstr_extension _ ->
              (enums, enums)
        in
        (after, List.rev_append (map_structure_item ~module_name ~enums item) mapped))
      (enums, []) items
  in
  List.rev mapped

and map_structure_item ~module_name ~enums (item : structure_item) =
  match item.pstr_desc with
  | Pstr_type (rec_flag, declarations) -> Derive.structure ~module_name ~enums item rec_flag declarations
  | Pstr_module binding -> [ { item with pstr_desc = Pstr_module (map_module_binding ~enums binding) } ]
  | Pstr_recmodule bindings ->
      [ { item with pstr_desc = Pstr_recmodule (List.map (map_module_binding ~enums) bindings) } ]
  | Pstr_modtype declaration ->
      [ { item with pstr_desc = Pstr_modtype (map_module_type_declaration declaration) } ]
  | Pstr_include include_ ->
      [
        {
          item with
          pstr_desc =
            Pstr_include { include_ with pincl_mod = map_module_expr ~module_name ~enums include_.pincl_mod };
        };
      ]
  | Pstr_eval _ | Pstr_value _ | Pstr_primitive _ | Pstr_typext _ | Pstr_exception _
  | Pstr_open _ | Pstr_class _ | Pstr_class_type _ | Pstr_attribute _ | Pstr_extension _ ->
      [ item ]

and map_module_binding ~enums (binding : module_binding) =
  { binding with pmb_expr = map_module_expr ~module_name:binding.pmb_name.txt ~enums binding.pmb_expr }

and map_module_expr ~module_name ~enums (expression : module_expr) =
  let desc =
    match expression.pmod_desc with
    | Pmod_structure items -> Pmod_structure (map_structure ~module_name ~enums items)
    | Pmod_constraint (inner, typ) ->
        Pmod_constraint (map_module_expr ~module_name ~enums inner, map_module_type ~module_name typ)
    | Pmod_functor (name, parameter, body) ->
        Pmod_functor
          ( name,
            Option.map (map_module_type ~module_name:name.txt) parameter,
            map_module_expr ~module_name ~enums body )
    | (Pmod_ident _ | Pmod_apply _ | Pmod_unpack _ | Pmod_extension _) as desc -> desc
  in
  { expression with pmod_desc = desc }

and map_module_type ~module_name (typ : module_type) =
  let desc =
    match typ.pmty_desc with
    | Pmty_signature items -> Pmty_signature (map_signature ~module_name items)
    | Pmty_functor (name, parameter, body) ->
        Pmty_functor
          ( name,
            Option.map (map_module_type ~module_name:name.txt) parameter,
            map_module_type ~module_name body )
    | Pmty_with (inner, constraints) -> Pmty_with (map_module_type ~module_name inner, constraints)
    | (Pmty_ident _ | Pmty_typeof _ | Pmty_extension _ | Pmty_alias _) as desc -> desc
  in
  { typ with pmty_desc = desc }

and map_module_type_declaration (declaration : module_type_declaration) =
  {
    declaration with
    pmtd_type = Option.map (map_module_type ~module_name:declaration.pmtd_name.txt) declaration.pmtd_type;
  }

and map_signature ~module_name items = List.concat_map (map_signature_item ~module_name) items

and map_signature_item ~module_name (item : signature_item) =
  match item.psig_desc with
  | Psig_type (rec_flag, declarations) -> Derive.signature item rec_flag declarations
  | Psig_module declaration ->
      [ { item with psig_desc = Psig_module (map_module_declaration declaration) } ]
  | Psig_recmodule declarations ->
      [ { item with psig_desc = Psig_recmodule (List.map map_module_declaration declarations) } ]
  | Psig_modtype declaration ->
      [ { item with psig_desc = Psig_modtype (map_module_type_declaration declaration) } ]
  | Psig_include include_ ->
      [
        {
          item with
          psig_desc =
            Psig_include { include_ with pincl_mod = map_module_type ~module_name include_.pincl_mod };
        };
      ]
  | Psig_value _ | Psig_typext _ | Psig_exception _ | Psig_open _ | Psig_class _
  | Psig_class_type _ | Psig_attribute _ | Psig_extension _ ->
      [ item ]

and map_module_declaration (declaration : module_declaration) =
  { declaration with pmd_type = map_module_type ~module_name:declaration.pmd_name.txt declaration.pmd_type }

let rewrite ~source_name (ast : Ast_io.ast) : Ast_io.ast =
  let module_name = Naming.module_of_source source_name in
  match ast with
  | Implementation structure -> Implementation (map_structure ~module_name ~enums:Enum_scope.empty structure)
  | Interface signature -> Interface (map_signature ~module_name signature)
