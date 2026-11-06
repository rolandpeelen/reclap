(* Names of the values that the PPX generates, and default command names.

   For a type named [t] the generated values are [args], [subcommand],
   [valueParser] and [parser]; for a type named [foo] they are [fooArgs],
   [fooSubcommand], [fooValueParser] and [fooParser]. A qualified type keeps
   its module path: [Level.t] gives [Level.valueParser]. *)

open Parsetree0

type kind = Args | Subcommand | Value_parser | Parser

let suffix = function
  | Args -> "Args"
  | Subcommand -> "Subcommand"
  | Value_parser -> "ValueParser"
  | Parser -> "Parser"

let value_name kind type_name =
  match type_name with
  | "t" -> String.uncapitalize_ascii (suffix kind)
  | _ -> type_name ^ suffix kind

(* [module_path] is the module part of a qualified type, such as [Git] in
   [Git.remote]. *)
let value_path kind ~(module_path : Longident.t option) type_name : Longident.t
    =
  let name = value_name kind type_name in
  match module_path with None -> Lident name | Some path -> Ldot (path, name)

(* "src/GitLike.res" is the module [GitLike]. *)
let module_of_source source_name =
  let base = Filename.basename source_name in
  match String.index_opt base '.' with
  | Some dot -> String.capitalize_ascii (String.sub base 0 dot)
  | None -> String.capitalize_ascii base

(* The default command name: the kebab-case type name, or the kebab-case
   module name for a type named [t]. *)
let command_name ~module_name type_name =
  match type_name with
  | "t" -> Casing.convert Kebab module_name
  | _ -> Casing.convert Kebab type_name
