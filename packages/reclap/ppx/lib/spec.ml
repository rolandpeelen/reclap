(* The typed description of what to generate for one annotated type.

   [Analyze] builds it from a type declaration and its attributes and reports
   every user error; [Codegen] turns it into code without further checks. *)

open Parsetree0

(* A type that a generated value refers to, such as [Git.remote]. *)
type type_ref = {
  module_path : Longident.t option;
  type_name : string;
  loc : Location.t;
}

type value_parser =
  | Builtin of string  (** [Clap.ValueParser.string] and so on *)
  | Derived of type_ref  (** the [@clap.valueEnum] value of a type *)
  | Custom of expression  (** [valueParser: expr] *)

type required = Inferred_required | Explicit_required of expression | Not_required

(* How a value-taking field is read from the matches; see the field type table. *)
type value_decoder = Get_one | Get_required | Get_many | Get_many_optional
type value_action = Set | Append

type valued = {
  value_action : value_action;
  value_parser : value_parser;
  default : expression option;  (** one value for [Set], an array for [Append] *)
  value_name : string;
  required : required;
  decoder : value_decoder;
}

type flag_action = Set_true | Set_false

type arg_kind =
  | Flag of flag_action  (** read with [Clap.Matches.getFlag] *)
  | Counter  (** [action: Count], read with [Clap.Matches.getCount] *)
  | Valued of valued

type arg = {
  id : string;
  kind : arg_kind;
  short : string option;
  long : string option;
  aliases : string list;  (** hidden *)
  visible_aliases : string list;
  env : string option;
  help : string option;
  long_help : string option;
  hide : bool;
}

type field_source =
  | Arg of arg
  | Flatten of type_ref
  | Subcommand_field of { subcommand : type_ref; optional : bool }
  | Skip of expression

type field = { field_name : string; field_loc : Location.t; source : field_source }

type command = {
  name : string;
  version : string option;
  about : string option;
  long_about : string option;
  author : string option;
}

type constructor_payload =
  | No_payload
  | Inline_record of field list
  | Args_payload of type_ref
  | Nested_subcommand of { subcommand : type_ref; optional : bool }

type subcommand_constructor = {
  constructor : string;
  constructor_loc : Location.t;
  command_name : string;
  command_about : string option;
  command_long_about : string option;
  command_aliases : string list;  (** hidden *)
  command_visible_aliases : string list;
  command_hide : bool;
  payload : constructor_payload;
}

type enum_value = {
  value_constructor : string;
  value_loc : Location.t;
  value_name : string;
  value_help : string option;
  value_aliases : string list;
  value_hide : bool;
}

type kind =
  | Args of field list
  | Subcommand of subcommand_constructor list
  | Value_enum of enum_value list
  | Parser_args of command * field list
  | Parser_subcommand of command * subcommand_constructor list

type t = { name : string; loc : Location.t; kind : kind }

(* The generated values that a type needs, in the same module, unqualified. *)
let field_dependencies fields =
  List.concat_map
    (fun field ->
      match field.source with
      | Arg { kind = Valued { value_parser = Derived target; _ }; _ } ->
          [ (Naming.Value_parser, target) ]
      | Arg _ | Skip _ -> []
      | Flatten target -> [ (Naming.Args, target) ]
      | Subcommand_field { subcommand; _ } -> [ (Naming.Subcommand, subcommand) ])
    fields

let constructor_dependencies constructors =
  List.concat_map
    (fun constructor ->
      match constructor.payload with
      | No_payload -> []
      | Inline_record fields -> field_dependencies fields
      | Args_payload target -> [ (Naming.Args, target) ]
      | Nested_subcommand { subcommand; _ } -> [ (Naming.Subcommand, subcommand) ])
    constructors

let local_dependencies spec =
  let refs =
    match spec.kind with
    | Args fields | Parser_args (_, fields) -> field_dependencies fields
    | Subcommand constructors | Parser_subcommand (_, constructors) ->
        constructor_dependencies constructors
    | Value_enum _ -> []
  in
  List.filter_map
    (fun (kind, target) ->
      match target.module_path with
      | None -> Some (Naming.value_name kind target.type_name)
      | Some _ -> None)
    refs

(* The names of the values generated for this type. *)
let generated_names spec =
  let names kinds = List.map (fun kind -> Naming.value_name kind spec.name) kinds in
  match spec.kind with
  | Args _ -> names [ Args ]
  | Subcommand _ -> names [ Subcommand ]
  | Value_enum _ -> names [ Value_parser ]
  | Parser_args _ -> names [ Args; Parser ]
  | Parser_subcommand _ -> names [ Subcommand; Parser ]
