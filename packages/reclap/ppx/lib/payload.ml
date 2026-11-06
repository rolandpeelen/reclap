(* Reading attribute payloads such as [@arg({short, long: "name", default: 1})].

   A payload is a record literal; a punned field ([{short}]) means "on, with the
   derived default". A single punned field parses as an identifier, so
   [@arg(long)] and [@arg({long})] are the same. *)

open Parsetree0

type value = Punned | Value of expression

type entry = {
  key : string;
  key_loc : Location.t;
  value : value;
}

let attribute_loc (({ loc; _ }, _) : attribute) = loc
let attribute_name (({ txt; _ }, _) : attribute) = txt

let find_all name (attributes : attributes) =
  List.filter (fun attribute -> attribute_name attribute = name) attributes

(* The text of the [res.doc] attribute that a [/** ... */] comment becomes. *)
let doc_comment (attributes : attributes) =
  List.find_map
    (fun (({ txt; _ }, payload) : attribute) ->
      match (txt, payload) with
      | ( "res.doc",
          PStr
            [
              {
                pstr_desc =
                  Pstr_eval
                    ({ pexp_desc = Pexp_constant (Pconst_string (text, _)); _ }, _);
                _;
              };
            ] ) ->
          Some text
      | _ -> None)
    attributes

let entry_of_field (({ txt; loc } : Longident.t Location.loc), (value : expression)) =
  match txt with
  | Lident key ->
      let value =
        match value.pexp_desc with
        | Pexp_ident { txt = Lident name; _ } when name = key -> Punned
        | _ -> Value value
      in
      Ok { key; key_loc = loc; value }
  | Ldot _ | Lapply _ -> Error loc

let shape_error errors loc name =
  Diagnostic.reportf errors loc
    "@%s expects a record of options, such as @%s({short, long}), or a single \
     option name, such as @%s(long)."
    name name name

let entries errors ((({ txt = name; loc }, payload) : attribute)) =
  match payload with
  | PStr [] -> []
  | PStr [ { pstr_desc = Pstr_eval (expression, _); _ } ] -> (
      match expression.pexp_desc with
      | Pexp_ident { txt = Lident key; loc = key_loc } ->
          [ { key; key_loc; value = Punned } ]
      | Pexp_record (fields, None) ->
          List.filter_map
            (fun field ->
              match entry_of_field field with
              | Ok entry -> Some entry
              | Error loc ->
                  Diagnostic.reportf errors loc
                    "@%s option names are plain names, such as `long`." name;
                  None)
            fields
      | _ ->
          shape_error errors expression.pexp_loc name;
          [])
  | PStr _ | PSig _ | PTyp _ | PPat _ ->
      shape_error errors loc name;
      []

(* Keeps the entries whose key is allowed and not repeated, and reports the
   others. *)
let check_keys errors ~attribute ~allowed entries =
  let rec go seen = function
    | [] -> []
    | entry :: rest when not (List.mem entry.key allowed) ->
        Diagnostic.reportf errors entry.key_loc
          "Unknown @%s option `%s`. Expected one of: %s." attribute entry.key
          (String.concat ", " allowed);
        go seen rest
    | entry :: rest when List.mem entry.key seen ->
        Diagnostic.reportf errors entry.key_loc "@%s option `%s` is repeated."
          attribute entry.key;
        go seen rest
    | entry :: rest -> entry :: go (entry.key :: seen) rest
  in
  go [] entries

let find key entries = List.find_opt (fun entry -> entry.key = key) entries
let value_loc entry = match entry.value with Punned -> entry.key_loc | Value e -> e.pexp_loc

let string_literal (expression : expression) =
  match expression.pexp_desc with
  | Pexp_constant (Pconst_string (text, _)) -> Some text
  | _ -> None

let string errors entry =
  match entry.value with
  | Value expression -> (
      match string_literal expression with
      | Some text -> Some text
      | None ->
          Diagnostic.reportf errors expression.pexp_loc
            "`%s` expects a string literal." entry.key;
          None)
  | Punned ->
      Diagnostic.reportf errors entry.key_loc
        "`%s` needs a value, such as %s: \"...\"." entry.key entry.key;
      None

let strings errors entry =
  let fail loc =
    Diagnostic.reportf errors loc
      "`%s` expects an array of string literals, such as %s: [\"a\", \"b\"]."
      entry.key entry.key;
    []
  in
  match entry.value with
  | Value { pexp_desc = Pexp_array items; pexp_loc; _ } ->
      let texts = List.filter_map string_literal items in
      if List.compare_lengths texts items = 0 then texts else fail pexp_loc
  | Value _ | Punned -> fail (value_loc entry)

(* A switch such as [hide]: punned means [true]. *)
let flag errors entry =
  match entry.value with
  | Punned -> true
  | Value { pexp_desc = Pexp_construct ({ txt = Lident "true"; _ }, None); _ } -> true
  | Value { pexp_desc = Pexp_construct ({ txt = Lident "false"; _ }, None); _ } -> false
  | Value { pexp_loc; _ } ->
      Diagnostic.reportf errors pexp_loc
        "`%s` expects `true` or `false`, or no value." entry.key;
      false

type name_setting = Derived | Explicit of string

(* [short], [long] and [env]: punned derives the name from the field. *)
let name_setting errors entry =
  match entry.value with
  | Punned -> Some Derived
  | Value _ -> Option.map (fun text -> Explicit text) (string errors entry)

let expression errors entry =
  match entry.value with
  | Value expression -> Some expression
  | Punned ->
      Diagnostic.reportf errors entry.key_loc
        "`%s` needs a value, such as %s: ..." entry.key entry.key;
      None

(* A constructor such as [Count] or [Clap.Arg.Count]: its last name. *)
let constructor errors entry =
  match entry.value with
  | Value { pexp_desc = Pexp_construct ({ txt = Lident name | Ldot (_, name); _ }, None); _ }
    ->
      Some (name, value_loc entry)
  | Value _ | Punned ->
      Diagnostic.reportf errors (value_loc entry)
        "`%s` expects a constructor, such as %s: Count." entry.key entry.key;
      None
