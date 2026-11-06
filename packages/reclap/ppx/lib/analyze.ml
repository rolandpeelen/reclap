(* Type declarations and their attributes to [Spec.t], with user-facing errors.

   Every function reports problems to the [Diagnostic.collector] in its
   context and keeps going, so one compilation shows as many errors as
   possible. A spec is only used when its declaration produced no error. *)

open Parsetree0
open Spec

type derive = Parser | Args_derive | Subcommand_derive | Value_enum_derive

let derives =
  [
    ("clap.parser", Parser);
    ("clap.args", Args_derive);
    ("clap.subcommand", Subcommand_derive);
    ("clap.valueEnum", Value_enum_derive);
  ]

let derive_attribute derive =
  match List.find_opt (fun (_, d) -> d = derive) derives with
  | Some (name, _) -> "@" ^ name
  | None -> "@clap"

let is_clap_attribute name = String.starts_with ~prefix:"clap." name

(* The attributes that the PPX consumes and removes from the output. *)
let is_reclap_attribute name =
  is_clap_attribute name || name = "arg" || name = "command" || name = "value"

type classification = Plain | Derive of derive | Invalid

(* Finds the [@clap.*] derive of a type declaration. *)
let classify errors (attributes : attributes) =
  let clap =
    List.filter
      (fun attribute -> is_clap_attribute (Payload.attribute_name attribute))
      attributes
  in
  let known =
    List.filter_map
      (fun ((({ txt; loc }, payload) : attribute)) ->
        match List.assoc_opt txt derives with
        | None ->
            Diagnostic.reportf errors loc
              "Unknown attribute @%s. Expected one of: @clap.parser, \
               @clap.args, @clap.subcommand, @clap.valueEnum."
              txt;
            None
        | Some derive ->
            (match payload with
            | PStr [] -> ()
            | PStr _ | PSig _ | PTyp _ | PPat _ ->
                Diagnostic.reportf errors loc
                  "@%s takes no payload. Put options in @command({...})." txt);
            Some (derive, loc))
      clap
  in
  match (clap, known) with
  | [], _ -> Plain
  | _, [ (derive, _) ] -> Derive derive
  | _, [] -> Invalid
  | _, _ :: (_, loc) :: _ ->
      Diagnostic.report errors loc
        "A type takes one of @clap.parser, @clap.args, @clap.subcommand and \
         @clap.valueEnum. @clap.parser already includes @clap.args or \
         @clap.subcommand.";
      Invalid

(* The only attribute named [name], reporting repetitions. *)
let single errors name (attributes : attributes) =
  match Payload.find_all name attributes with
  | [] -> None
  | first :: rest ->
      List.iter
        (fun attribute ->
          Diagnostic.reportf errors (Payload.attribute_loc attribute)
            "@%s is repeated. Put all options in one @%s({...})." name name)
        rest;
      Some first

(* Reports [@clap.*], [@arg], [@command] and [@value] attributes that are not
   valid in this position. [allowed] are the ones that are. *)
let reject_misplaced errors ~position ~allowed (attributes : attributes) =
  List.iter
    (fun attribute ->
      let name = Payload.attribute_name attribute in
      if is_reclap_attribute name && not (List.mem name allowed) then
        Diagnostic.reportf errors (Payload.attribute_loc attribute)
          "@%s is not valid on %s." name position)
    attributes

let options errors ~name ~allowed attributes =
  match single errors name attributes with
  | None -> []
  | Some attribute ->
      Payload.check_keys errors ~attribute:name ~allowed
        (Payload.entries errors attribute)

let string_option errors key entries =
  Option.bind (Payload.find key entries) (Payload.string errors)

let flag_option errors key entries =
  match Payload.find key entries with
  | None -> false
  | Some entry -> Payload.flag errors entry

(* [alias: "x"] and [aliases: ["y", "z"]], or their [visible] variants. *)
let aliases ?(visible = false) errors entries =
  let one, many = if visible then ("visibleAlias", "visibleAliases") else ("alias", "aliases") in
  let single = Option.to_list (string_option errors one entries) in
  let many =
    match Payload.find many entries with
    | None -> []
    | Some entry -> Payload.strings errors entry
  in
  single @ many

let casing_option errors key entries ~default =
  match Payload.find key entries with
  | None -> default
  | Some entry -> (
      match Payload.string errors entry with
      | None -> default
      | Some name -> (
          match Casing.of_string name with
          | Some casing -> casing
          | None ->
              Diagnostic.reportf errors (Payload.value_loc entry)
                "Unknown `%s` value \"%s\". Expected one of: %s." key name
                (String.concat ", "
                   (List.map (fun (name, _) -> "\"" ^ name ^ "\"") Casing.all));
              default))

let doc_comment attributes = Option.bind (Payload.doc_comment attributes) Doc_comment.parse
let doc_summary doc = Option.map (fun (doc : Doc_comment.t) -> doc.summary) doc
let doc_long doc = Option.bind doc (fun (doc : Doc_comment.t) -> doc.long)

(* Help and long help: explicit options override the doc comment. *)
let help_texts errors ~help ~long_help entries attributes =
  let doc = doc_comment attributes in
  let pick key fallback =
    match string_option errors key entries with
    | Some text -> Some text
    | None -> fallback
  in
  (pick help (doc_summary doc), pick long_help (doc_long doc))

(* Types *)

let rec type_to_string (typ : core_type) =
  match typ.ptyp_desc with
  | Ptyp_constr ({ txt; _ }, []) -> longident_to_string txt
  | Ptyp_constr ({ txt; _ }, args) ->
      longident_to_string txt ^ "<"
      ^ String.concat ", " (List.map type_to_string args)
      ^ ">"
  | Ptyp_var name -> "'" ^ name
  | Ptyp_tuple items -> "(" ^ String.concat ", " (List.map type_to_string items) ^ ")"
  | Ptyp_any | Ptyp_arrow _ | Ptyp_object _ | Ptyp_class _ | Ptyp_alias _
  | Ptyp_variant _ | Ptyp_poly _ | Ptyp_package _ | Ptyp_extension _ ->
      "this type"

and longident_to_string : Longident.t -> string = function
  | Lident name -> name
  | Ldot (path, name) -> longident_to_string path ^ "." ^ name
  | Lapply (f, x) -> longident_to_string f ^ "(" ^ longident_to_string x ^ ")"

(* A named type without parameters, such as [command] or [Git.remote]. *)
let type_ref errors ~what (typ : core_type) =
  let fail () =
    Diagnostic.reportf errors typ.ptyp_loc
      "%s must be a named type without parameters, such as `command` or \
       `Remote.t`, not `%s`."
      what (type_to_string typ);
    None
  in
  match typ.ptyp_desc with
  | Ptyp_constr ({ txt = Lident type_name; loc }, []) ->
      Some { module_path = None; type_name; loc }
  | Ptyp_constr ({ txt = Ldot (module_path, type_name); loc }, []) ->
      Some { module_path = Some module_path; type_name; loc }
  | _ -> fail ()

let option_payload (typ : core_type) =
  match typ.ptyp_desc with
  | Ptyp_constr ({ txt = Lident "option"; _ }, [ inner ]) -> Some inner
  | _ -> None

type shape =
  | Bool_shape
  | Scalar of core_type
  | Optional of core_type
  | Many of core_type
  | Many_optional of core_type

let shape (typ : core_type) =
  match typ.ptyp_desc with
  | Ptyp_constr ({ txt = Lident "bool"; _ }, []) -> Bool_shape
  | Ptyp_constr
      ( { txt = Lident "option"; _ },
        [ { ptyp_desc = Ptyp_constr ({ txt = Lident "array"; _ }, [ element ]); _ } ] )
    ->
      Many_optional element
  | Ptyp_constr ({ txt = Lident "option"; _ }, [ element ]) -> Optional element
  | Ptyp_constr ({ txt = Lident "array"; _ }, [ element ]) -> Many element
  | _ -> Scalar typ

let is_int (typ : core_type) =
  match typ.ptyp_desc with
  | Ptyp_constr ({ txt = Lident "int"; _ }, []) -> true
  | _ -> false

(* The value parser for the element type of a field. *)
let element_parser errors ~explicit (element : core_type) =
  match explicit with
  | Some expression -> Some (Custom expression)
  | None -> (
      match element.ptyp_desc with
      | Ptyp_constr ({ txt = Lident (("string" | "int" | "float" | "bool") as name); _ }, [])
        ->
          Some (Builtin name)
      | Ptyp_constr ({ txt = Lident ("option" | "array"); _ }, _) ->
          Diagnostic.reportf errors element.ptyp_loc
            "Unsupported field type: `%s` cannot be nested here. Fields can be \
             `T`, `option<T>`, `array<T>` or `option<array<T>>`."
            (type_to_string element);
          None
      | _ ->
          Option.map
            (fun target -> Derived target)
            (type_ref errors ~what:"An argument value type" element))

(* Fields *)

type context = {
  errors : Diagnostic.collector;
  casing : Casing.t;  (** for long names and subcommand and value names *)
  env_casing : Casing.t;
}

let utf8_length text =
  let count = ref 0 in
  String.iter (fun c -> if Char.code c land 0xC0 <> 0x80 then incr count) text;
  !count

let first_character text =
  match text with
  | "" -> None
  | _ ->
      let length = ref 1 in
      while !length < String.length text && Char.code text.[!length] land 0xC0 = 0x80 do
        incr length
      done;
      Some (String.sub text 0 !length)

let arg_keys =
  [
    "short"; "long"; "env"; "default"; "help"; "longHelp"; "valueName"; "id";
    "alias"; "aliases"; "visibleAlias"; "visibleAliases"; "action"; "required"; "valueParser"; "hide"; "skip";
  ]

type explicit_action = Set_action | Append_action | Set_true_action | Set_false_action | Count_action

let action_names =
  [
    ("Set", Set_action);
    ("Append", Append_action);
    ("SetTrue", Set_true_action);
    ("SetFalse", Set_false_action);
    ("Count", Count_action);
  ]

let explicit_action errors entries =
  Option.bind (Payload.find "action" entries) (fun entry ->
      Option.bind (Payload.constructor errors entry) (fun (name, loc) ->
          match List.assoc_opt name action_names with
          | Some action -> Some (action, name)
          | None ->
              Diagnostic.reportf errors loc
                "Unknown action `%s`. Expected one of: Set, Append, SetTrue, \
                 SetFalse, Count."
                name;
              None))

type resolved_kind =
  | Resolved_flag of flag_action
  | Resolved_counter
  | Resolved_valued of value_action * value_decoder * core_type

(* Combines the field type with an explicit action. *)
let resolve_kind errors (field : label_declaration) action =
  let typ = field.pld_type in
  let mismatch name =
    Diagnostic.reportf errors field.pld_loc
      "`action: %s` does not fit the field type `%s`." name (type_to_string typ);
    None
  in
  match (shape typ, action) with
  | Bool_shape, (None | Some (Set_true_action, _)) -> Some (Resolved_flag Set_true)
  | Bool_shape, Some (Set_false_action, _) -> Some (Resolved_flag Set_false)
  | Bool_shape, Some (Set_action, _) -> Some (Resolved_valued (Set, Get_required, typ))
  | Scalar element, Some (Count_action, _) when is_int element -> Some Resolved_counter
  | Scalar _, Some (Count_action, _) ->
      Diagnostic.reportf errors field.pld_loc
        "`action: Count` needs a field of type `int`, not `%s`." (type_to_string typ);
      None
  | Scalar element, (None | Some (Set_action, _)) ->
      Some (Resolved_valued (Set, Get_required, element))
  | Optional element, (None | Some (Set_action, _)) ->
      Some (Resolved_valued (Set, Get_one, element))
  | Many element, (None | Some (Append_action, _)) ->
      Some (Resolved_valued (Append, Get_many, element))
  | Many_optional element, (None | Some (Append_action, _)) ->
      Some (Resolved_valued (Append, Get_many_optional, element))
  | (Bool_shape | Scalar _ | Optional _ | Many _ | Many_optional _), Some (_, name) ->
      mismatch name

(* Options that only value-taking arguments accept. *)
let reject_value_options errors ~kind_name entries =
  List.iter
    (fun key ->
      match Payload.find key entries with
      | None -> ()
      | Some entry ->
          Diagnostic.reportf errors entry.key_loc
            "`%s` is not supported for %s, which take no value." key kind_name)
    [ "default"; "valueName"; "valueParser"; "required" ]

let derive_name ~field_name ~casing (setting : Payload.name_setting) =
  match setting with
  | Derived -> Some (Casing.convert casing field_name)
  | Explicit name -> Some name

let arg_field ctx (field : label_declaration) entries =
  let errors = ctx.errors in
  let field_name = field.pld_name.txt in
  let entries = Payload.check_keys errors ~attribute:"arg" ~allowed:arg_keys entries in
  match Payload.find "skip" entries with
  | Some skip ->
      List.iter
        (fun (entry : Payload.entry) ->
          if entry.key <> "skip" then
            Diagnostic.reportf errors entry.key_loc
              "`skip` cannot be combined with other @arg options.")
        entries;
      Option.map
        (fun expression -> Skip expression)
        (Payload.expression errors skip)
  | None -> (
      let setting key = Option.bind (Payload.find key entries) (Payload.name_setting errors) in
      let long =
        Option.bind (setting "long") (derive_name ~field_name ~casing:ctx.casing)
      in
      let short =
        match Payload.find "short" entries with
        | None -> None
        | Some entry -> (
            match Payload.name_setting errors entry with
            | None -> None
            | Some Derived -> first_character (Casing.convert ctx.casing field_name)
            | Some (Explicit name) when utf8_length name = 1 -> Some name
            | Some (Explicit name) ->
                Diagnostic.reportf errors (Payload.value_loc entry)
                  "`short` must be one character, not \"%s\"." name;
                None)
      in
      let env =
        Option.bind (setting "env") (derive_name ~field_name ~casing:ctx.env_casing)
      in
      let help, long_help = help_texts errors ~help:"help" ~long_help:"longHelp" entries field.pld_attributes in
      let id = Option.value (string_option errors "id" entries) ~default:field_name in
      let hide = flag_option errors "hide" entries in
      let visible_aliases = aliases ~visible:true errors entries in
      let aliases = aliases errors entries in
      let named = short <> None || long <> None in
      let unnamed kind_name =
        Diagnostic.reportf errors field.pld_loc
          "%s must be named: add `short` or `long`, as in @arg({short, long}). \
           Positional arguments take values."
          kind_name
      in
      let kind =
        match resolve_kind errors field (explicit_action errors entries) with
        | None -> None
        | Some (Resolved_flag action) ->
            reject_value_options errors ~kind_name:"flags" entries;
            if not named then unnamed "A `bool` flag";
            Some (Flag action)
        | Some Resolved_counter ->
            reject_value_options errors ~kind_name:"`Count` arguments" entries;
            if not named then unnamed "A `Count` argument";
            Some Counter
        | Some (Resolved_valued (value_action, decoder, element)) ->
            let explicit_parser =
              Option.bind (Payload.find "valueParser" entries) (Payload.expression errors)
            in
            let default = Option.bind (Payload.find "default" entries) (Payload.expression errors) in
            let required =
              match Option.bind (Payload.find "required" entries) (Payload.expression errors) with
              | Some expression -> Explicit_required expression
              | None -> (
                  match (decoder, default) with
                  | Get_required, None -> Inferred_required
                  | (Get_required | Get_one | Get_many | Get_many_optional), _ -> Not_required)
            in
            let value_name =
              match string_option errors "valueName" entries with
              | Some name -> name
              | None -> Casing.convert Screaming_snake field_name
            in
            Option.map
              (fun value_parser ->
                Valued { value_action; value_parser; default; value_name; required; decoder })
              (element_parser errors ~explicit:explicit_parser element)
      in
      Option.map
        (fun kind ->
          Arg { id; kind; short; long; aliases; visible_aliases; env; help; long_help; hide })
        kind)

let command_field errors (field : label_declaration) entries =
  let entries =
    Payload.check_keys errors ~attribute:"command" ~allowed:[ "subcommand"; "flatten" ] entries
  in
  let subcommand = flag_option errors "subcommand" entries in
  let flatten = flag_option errors "flatten" entries in
  match (subcommand, flatten) with
  | true, true ->
      Diagnostic.report errors field.pld_loc
        "A field is either @command({subcommand}) or @command({flatten}), not both.";
      None
  | false, false ->
      Diagnostic.report errors field.pld_loc
        "@command on a field needs `subcommand` or `flatten`.";
      None
  | false, true ->
      Option.map
        (fun target -> Flatten target)
        (type_ref errors ~what:"A @command({flatten}) field type" field.pld_type)
  | true, false ->
      let optional, typ =
        match option_payload field.pld_type with
        | Some inner -> (true, inner)
        | None -> (false, field.pld_type)
      in
      Option.map
        (fun subcommand -> Subcommand_field { subcommand; optional })
        (type_ref errors ~what:"A @command({subcommand}) field type" typ)

let is_optional_field (field : label_declaration) =
  List.exists (fun attribute -> Payload.attribute_name attribute = "res.optional") field.pld_attributes

let analyze_field ctx (field : label_declaration) =
  let errors = ctx.errors in
  let attributes = field.pld_attributes in
  reject_misplaced errors ~position:"record fields" ~allowed:[ "arg"; "command" ] attributes;
  let source =
    if is_optional_field field then (
      Diagnostic.reportf errors field.pld_loc
        "Optional record fields (`%s?: ...`) are not supported. Use `%s: \
         option<...>` for an optional argument."
        field.pld_name.txt field.pld_name.txt;
      None)
    else
      match (single errors "arg" attributes, single errors "command" attributes) with
      | Some _, Some command ->
          Diagnostic.report errors (Payload.attribute_loc command)
            "@arg and @command cannot be combined on one field.";
          None
      | None, Some command -> command_field errors field (Payload.entries errors command)
      | Some arg, None -> arg_field ctx field (Payload.entries errors arg)
      | None, None -> arg_field ctx field []
  in
  Option.map
    (fun source -> { field_name = field.pld_name.txt; field_loc = field.pld_loc; source })
    source

let all_or_none results =
  if List.for_all Option.is_some results then Some (List.filter_map Fun.id results) else None

let analyze_fields ctx fields =
  let fields = List.map (analyze_field ctx) fields in
  Option.bind (all_or_none fields) (fun fields ->
      match
        List.filter
          (fun field ->
            match field.source with
            | Subcommand_field _ -> true
            | Arg _ | Flatten _ | Skip _ -> false)
          fields
      with
      | _ :: second :: _ ->
          Diagnostic.report ctx.errors second.field_loc
            "A record can have only one @command({subcommand}) field.";
          None
      | [] | [ _ ] -> Some fields)

(* Subcommand constructors *)

let constructor_keys =
  [
    "name"; "about"; "longAbout"; "alias"; "aliases"; "visibleAlias"; "visibleAliases"; "hide";
    "subcommand";
  ]

let constructor_payload ctx (constructor : constructor_declaration) ~nested =
  let errors = ctx.errors in
  let loc = constructor.pcd_loc in
  match (constructor.pcd_args, nested) with
  | Pcstr_tuple [], false -> Some No_payload
  | Pcstr_tuple [], true ->
      Diagnostic.report errors loc
        "@command({subcommand}) on a constructor needs a payload type, as in \
         Remote(remote).";
      None
  | Pcstr_tuple [ typ ], true ->
      let optional, typ =
        match option_payload typ with Some inner -> (true, inner) | None -> (false, typ)
      in
      Option.map
        (fun subcommand -> Nested_subcommand { subcommand; optional })
        (type_ref errors ~what:"A nested subcommand payload" typ)
  | Pcstr_tuple [ typ ], false ->
      Option.map
        (fun target -> Args_payload target)
        (type_ref errors ~what:"A subcommand payload (a @clap.args type)" typ)
  | Pcstr_tuple _, _ ->
      Diagnostic.report errors loc
        "A subcommand constructor takes no payload, one @clap.args type, or an \
         inline record.";
      None
  | Pcstr_record fields, false ->
      Option.map (fun fields -> Inline_record fields) (analyze_fields ctx fields)
  | Pcstr_record _, true ->
      Diagnostic.report errors loc
        "@command({subcommand}) on a constructor needs a payload type, not an \
         inline record.";
      None

let analyze_subcommand_constructor ctx (constructor : constructor_declaration) =
  let errors = ctx.errors in
  let attributes = constructor.pcd_attributes in
  reject_misplaced errors ~position:"subcommand constructors" ~allowed:[ "command" ] attributes;
  (match constructor.pcd_res with
  | None -> ()
  | Some typ ->
      Diagnostic.report errors typ.ptyp_loc "GADT constructors are not supported.");
  let entries = options errors ~name:"command" ~allowed:constructor_keys attributes in
  let command_name =
    match string_option errors "name" entries with
    | Some name -> name
    | None -> Casing.convert ctx.casing constructor.pcd_name.txt
  in
  let about, long_about = help_texts errors ~help:"about" ~long_help:"longAbout" entries attributes in
  let visible_aliases = aliases ~visible:true errors entries in
  let aliases = aliases errors entries in
  let hide = flag_option errors "hide" entries in
  let nested = flag_option errors "subcommand" entries in
  Option.map
    (fun payload ->
      {
        constructor = constructor.pcd_name.txt;
        constructor_loc = constructor.pcd_loc;
        command_name;
        command_about = about;
        command_long_about = long_about;
        command_aliases = aliases;
        command_visible_aliases = visible_aliases;
        command_hide = hide;
        payload;
      })
    (constructor_payload ctx constructor ~nested)

(* Value enum constructors *)

let value_keys = [ "name"; "help"; "alias"; "aliases"; "hide"; "skip" ]

(* [None] for errors and for skipped constructors; errors are in the collector. *)
let analyze_enum_constructor ctx (constructor : constructor_declaration) =
  let errors = ctx.errors in
  let attributes = constructor.pcd_attributes in
  reject_misplaced errors ~position:"@clap.valueEnum constructors" ~allowed:[ "value" ] attributes;
  (match (constructor.pcd_args, constructor.pcd_res) with
  | Pcstr_tuple [], None -> ()
  | (Pcstr_tuple _ | Pcstr_record _), _ ->
      Diagnostic.reportf errors constructor.pcd_loc
        "@clap.valueEnum constructors cannot have payloads, but `%s` has one."
        constructor.pcd_name.txt);
  let entries = options errors ~name:"value" ~allowed:value_keys attributes in
  let name =
    match string_option errors "name" entries with
    | Some name -> name
    | None -> Casing.convert ctx.casing constructor.pcd_name.txt
  in
  let help =
    match string_option errors "help" entries with
    | Some help -> Some help
    | None -> doc_summary (doc_comment attributes)
  in
  let aliases = aliases errors entries in
  let hide = flag_option errors "hide" entries in
  match flag_option errors "skip" entries with
  | true -> None
  | false ->
      Some
        {
          value_constructor = constructor.pcd_name.txt;
          value_loc = constructor.pcd_loc;
          value_name = name;
          value_help = help;
          value_aliases = aliases;
          value_hide = hide;
        }

(* Type declarations *)

let parser_keys = [ "name"; "version"; "about"; "longAbout"; "author"; "renameAll"; "renameAllEnv" ]
let rename_keys = [ "renameAll"; "renameAllEnv" ]

let context errors entries =
  {
    errors;
    casing = casing_option errors "renameAll" entries ~default:Kebab;
    env_casing = casing_option errors "renameAllEnv" entries ~default:Screaming_snake;
  }

let analyze_command errors ~module_name (declaration : type_declaration) entries =
  let about, long_about =
    help_texts errors ~help:"about" ~long_help:"longAbout" entries declaration.ptype_attributes
  in
  {
    name =
      (match string_option errors "name" entries with
      | Some name -> name
      | None -> Naming.command_name ~module_name declaration.ptype_name.txt);
    version = string_option errors "version" entries;
    about;
    long_about;
    author = string_option errors "author" entries;
  }

let kind_mismatch errors (declaration : type_declaration) derive =
  let message =
    match (derive, declaration.ptype_kind) with
    | Args_derive, Ptype_variant _ ->
        "@clap.args needs a record type. Use @clap.subcommand for a variant."
    | Subcommand_derive, Ptype_record _ ->
        "@clap.subcommand needs a variant type. Use @clap.args for a record."
    | Value_enum_derive, Ptype_record _ ->
        "@clap.valueEnum needs a variant of constructors without payloads."
    | _, (Ptype_abstract | Ptype_open | Ptype_record _ | Ptype_variant _) ->
        Printf.sprintf "%s needs a record or variant definition."
          (derive_attribute derive)
  in
  Diagnostic.report errors declaration.ptype_loc message

let check_parameters errors (declaration : type_declaration) =
  match declaration.ptype_params with
  | [] -> ()
  | _ :: _ ->
      Diagnostic.report errors declaration.ptype_loc
        "@clap types cannot have type parameters."

let analyze errors ~module_name derive (declaration : type_declaration) =
  check_parameters errors declaration;
  let attributes = declaration.ptype_attributes in
  let command_entries allowed =
    reject_misplaced errors ~position:"this type" ~allowed:[ "command" ]
      (List.filter (fun a -> not (is_clap_attribute (Payload.attribute_name a))) attributes);
    options errors ~name:"command" ~allowed attributes
  in
  let kind =
    match (derive, declaration.ptype_kind) with
    | Parser, Ptype_record fields ->
        let entries = command_entries parser_keys in
        let command = analyze_command errors ~module_name declaration entries in
        Option.map
          (fun fields -> Parser_args (command, fields))
          (analyze_fields (context errors entries) fields)
    | Parser, Ptype_variant constructors ->
        let entries = command_entries parser_keys in
        let command = analyze_command errors ~module_name declaration entries in
        let ctx = context errors entries in
        Option.map
          (fun constructors -> Parser_subcommand (command, constructors))
          (all_or_none (List.map (analyze_subcommand_constructor ctx) constructors))
    | Args_derive, Ptype_record fields ->
        let ctx = context errors (command_entries rename_keys) in
        Option.map (fun fields -> Args fields) (analyze_fields ctx fields)
    | Subcommand_derive, Ptype_variant constructors ->
        let ctx = context errors (command_entries rename_keys) in
        Option.map
          (fun constructors -> Subcommand constructors)
          (all_or_none (List.map (analyze_subcommand_constructor ctx) constructors))
    | Value_enum_derive, Ptype_variant constructors ->
        reject_misplaced errors ~position:"@clap.valueEnum types (use @value({renameAll}))"
          ~allowed:[ "value" ]
          (List.filter (fun a -> not (is_clap_attribute (Payload.attribute_name a))) attributes);
        let entries = options errors ~name:"value" ~allowed:[ "renameAll" ] attributes in
        let ctx = context errors entries in
        Some (Value_enum (List.filter_map (analyze_enum_constructor ctx) constructors))
    | (Parser | Args_derive | Subcommand_derive | Value_enum_derive), _ ->
        kind_mismatch errors declaration derive;
        None
  in
  Option.map
    (fun kind -> { name = declaration.ptype_name.txt; loc = declaration.ptype_loc; kind })
    kind

(* In an interface only the kind of the type matters: the generated values'
   types. Abstract types are fine for every derive but @clap.parser. *)
let analyze_signature errors derive (declaration : type_declaration) =
  check_parameters errors declaration;
  let kinds : Naming.kind list option =
    match (derive, declaration.ptype_kind) with
    | Parser, Ptype_record _ -> Some [ Args; Parser ]
    | Parser, Ptype_variant _ -> Some [ Subcommand; Parser ]
    | Parser, (Ptype_abstract | Ptype_open) ->
        Diagnostic.report errors declaration.ptype_loc
          "@clap.parser in an interface needs the type's definition, to tell a \
           record from a variant.";
        None
    | Args_derive, (Ptype_record _ | Ptype_abstract) -> Some [ Args ]
    | Subcommand_derive, (Ptype_variant _ | Ptype_abstract) -> Some [ Subcommand ]
    | Value_enum_derive, (Ptype_variant _ | Ptype_abstract) -> Some [ Value_parser ]
    | (Args_derive | Subcommand_derive | Value_enum_derive), _ ->
        kind_mismatch errors declaration derive;
        None
  in
  kinds

(* Removes the attributes that the PPX consumed. *)
let strip (declaration : type_declaration) =
  let keep attributes =
    List.filter (fun a -> not (is_reclap_attribute (Payload.attribute_name a))) attributes
  in
  let label (field : label_declaration) = { field with pld_attributes = keep field.pld_attributes } in
  let constructor (c : constructor_declaration) =
    {
      c with
      pcd_attributes = keep c.pcd_attributes;
      pcd_args =
        (match c.pcd_args with
        | Pcstr_tuple _ as args -> args
        | Pcstr_record fields -> Pcstr_record (List.map label fields));
    }
  in
  {
    declaration with
    ptype_attributes = keep declaration.ptype_attributes;
    ptype_kind =
      (match declaration.ptype_kind with
      | Ptype_record fields -> Ptype_record (List.map label fields)
      | Ptype_variant constructors -> Ptype_variant (List.map constructor constructors)
      | (Ptype_abstract | Ptype_open) as kind -> kind);
  }
