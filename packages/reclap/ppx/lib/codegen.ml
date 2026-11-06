(* [Spec.t] to the generated values. See "Generated code" in docs/design.md.

   Generated identifiers start with [__clap_] so they cannot capture user
   names, and runtime calls are fully qualified as [Clap.X.y]. Field values
   are bound to [__clap_field_<name>], which cannot clash with
   [__clap_command], [__clap_matches] or [__clap_error]. *)

open Parsetree0
open Spec

let command_var = "__clap_command"
let matches_var = "__clap_matches"
let error_var = "__clap_error"
let value_var = "__clap_value"

(* Field names such as [\"dry-run"] are not identifiers: their other
   characters become [_], with a hash of the name to keep them apart. *)
let field_var name =
  let is_ident_char c =
    (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c = '_'
  in
  let sanitized = String.map (fun c -> if is_ident_char c then c else '_') name in
  if sanitized = name then "__clap_field_" ^ name
  else Printf.sprintf "__clap_field_%s_%d" sanitized (Hashtbl.hash name)

let call loc path args = Ast.apply loc (Ast.clap loc path) args
let lid name = Longident.Lident name

(* [|> f] for an optional setting. *)
let with_option value f expression =
  match value with None -> expression | Some value -> f value expression

let with_flag flag f expression = if flag then f expression else expression

(* The value generated for another type, located at the type reference so an
   unbound value points at the field that needs it. *)
let generated_value kind (target : type_ref) =
  Ast.ident (Ast.ghost target.loc)
    (Naming.value_path kind ~module_path:target.module_path target.type_name)

let value_parser loc = function
  | Builtin name -> Ast.clap loc [ "ValueParser"; name ]
  | Derived target -> generated_value Value_parser target
  | Custom expression -> expression

let result_switch loc scrutinee ~ok_pattern ~ok =
  Ast.match_ loc scrutinee
    [
      Ast.case
        (Ast.pconstruct loc (lid "Error") (Some (Ast.pvar loc error_var)))
        (Ast.construct loc (lid "Error") (Some (Ast.var loc error_var)));
      Ast.case (Ast.pconstruct loc (lid "Ok") (Some ok_pattern)) ok;
    ]

let ok loc value = Ast.construct loc (lid "Ok") (Some value)

(* Arguments *)

let action_constructor = function
  | Flag Set_true -> "SetTrue"
  | Flag Set_false -> "SetFalse"
  | Counter -> "Count"
  | Valued { value_action = Set; _ } -> "Set"
  | Valued { value_action = Append; _ } -> "Append"

let arg_expression loc (arg : arg) =
  let arg_call name args expression = call loc [ "Arg"; name ] (expression :: args) in
  let string = Ast.string loc in
  let valued f expression =
    match arg.kind with Valued valued -> f valued expression | Flag _ | Counter -> expression
  in
  call loc [ "Arg"; "make" ] [ string arg.id ]
  |> valued (fun valued -> arg_call "valueName" [ string valued.value_name ])
  |> valued (fun valued ->
         match valued.required with
         | Inferred_required -> arg_call "required" [ Ast.bool loc true ]
         | Explicit_required required -> arg_call "required" [ required ]
         | Not_required -> Fun.id)
  |> arg_call "action"
       [ Ast.construct loc (Ast.longident "Clap" [ "Arg"; action_constructor arg.kind ]) None ]
  |> valued (fun valued -> arg_call "valueParser" [ value_parser loc valued.value_parser ])
  |> valued (fun valued ->
         with_option valued.default (fun default ->
             let name =
               match valued.value_action with Set -> "defaultValue" | Append -> "defaultValues"
             in
             arg_call name [ value_parser loc valued.value_parser; default ]))
  |> with_option arg.short (fun short -> arg_call "short" [ string short ])
  |> with_option arg.long (fun long -> arg_call "long" [ string long ])
  |> fun expression ->
  List.fold_left (fun e alias -> arg_call "alias" [ string alias ] e) expression arg.aliases
  |> fun expression ->
  List.fold_left
    (fun e alias -> arg_call "visibleAlias" [ string alias ] e)
    expression arg.visible_aliases
  |> with_option arg.env (fun env -> arg_call "env" [ string env ])
  |> with_option arg.help (fun help -> arg_call "help" [ string help ])
  |> with_option arg.long_help (fun long_help -> arg_call "longHelp" [ string long_help ])
  |> with_flag arg.hide (fun e -> call loc [ "Arg"; "hide" ] [ e ])

(* Record fields: augmenting a command and decoding the matches *)

(* Adds the field to a command, or [None] for skipped fields. *)
let augment_step (field : field) : (expression -> expression) option =
  let loc = Ast.ghost field.field_loc in
  match field.source with
  | Arg arg -> Some (fun command -> call loc [ "Command"; "arg" ] [ command; arg_expression loc arg ])
  | Flatten target ->
      Some (fun command -> call loc [ "Args"; "augment" ] [ generated_value Args target; command ])
  | Subcommand_field { subcommand; optional } ->
      let name = if optional then "augment" else "augmentRequired" in
      Some
        (fun command ->
          call loc [ "Subcommand"; name ] [ generated_value Subcommand subcommand; command ])
  | Skip _ -> None

(* [let __clap_command = step1(__clap_command); ...; stepN(__clap_command)] *)
let augment_body loc steps =
  let command = Ast.var loc command_var in
  let rec chain = function
    | [] -> command
    | [ last ] -> last command
    | step :: rest -> Ast.let_ loc (Ast.pvar loc command_var) (step command) (chain rest)
  in
  chain steps

(* [step3(step2(step1(init)))], for subcommands of a subcommand list. *)
let augment_nested init steps = List.fold_left (fun command step -> step command) init steps

type decoded = Fallible of expression | Infallible of expression

let decode_field (field : field) =
  let loc = Ast.ghost field.field_loc in
  let matches = Ast.var loc matches_var in
  match field.source with
  | Arg { id; kind = Flag _; _ } -> Infallible (call loc [ "Matches"; "getFlag" ] [ matches; Ast.string loc id ])
  | Arg { id; kind = Counter; _ } ->
      Infallible (call loc [ "Matches"; "getCount" ] [ matches; Ast.string loc id ])
  | Arg { id; kind = Valued valued; _ } ->
      let getter =
        match valued.decoder with
        | Get_one -> "getOne"
        | Get_required -> "getRequired"
        | Get_many -> "getMany"
        | Get_many_optional -> "getManyOptional"
      in
      Fallible
        (call loc [ "Matches"; getter ]
           [ matches; Ast.string loc id; value_parser loc valued.value_parser ])
  | Flatten target ->
      Fallible (call loc [ "Args"; "fromMatches" ] [ generated_value Args target; matches ])
  | Subcommand_field { subcommand; optional } ->
      let name = if optional then "fromMatchesOptional" else "fromMatches" in
      Fallible
        (call loc [ "Subcommand"; name ] [ generated_value Subcommand subcommand; matches ])
  | Skip expression -> Infallible expression

(* Decodes every field in order, then [finish] builds the value from the
   [(field name, variable)] pairs. *)
let decode_fields loc fields ~finish =
  let rec go = function
    | [] -> finish (List.map (fun field -> (field.field_name, Ast.var loc (field_var field.field_name))) fields)
    | field :: rest -> (
        let pattern = Ast.pvar (Ast.ghost field.field_loc) (field_var field.field_name) in
        match decode_field field with
        | Infallible value -> Ast.let_ loc pattern value (go rest)
        | Fallible value -> result_switch loc value ~ok_pattern:pattern ~ok:(go rest))
  in
  go fields

let reads_matches fields =
  List.exists
    (fun field ->
      match field.source with Skip _ -> false | Arg _ | Flatten _ | Subcommand_field _ -> true)
    fields

let matches_pattern loc ~used = if used then Ast.pvar loc matches_var else Ast.pany loc

let self_type loc (spec : Spec.t) = Ast.typ loc (lid spec.name) []

let args_value loc (spec : Spec.t) fields =
  let augment = augment_body loc (List.filter_map augment_step fields) in
  let decode =
    decode_fields loc fields ~finish:(fun values ->
        ok loc (Ast.constraint_ loc (Ast.record loc values) (self_type loc spec)))
  in
  call loc [ "Args"; "make" ]
    [
      Ast.lambda loc (Ast.pvar loc command_var) augment;
      Ast.lambda loc (matches_pattern loc ~used:(reads_matches fields)) decode;
    ]

(* Subcommands *)

let constructor_command loc (constructor : subcommand_constructor) =
  let command_call name args expression = call loc [ "Command"; name ] (expression :: args) in
  let string = Ast.string loc in
  let init =
    call loc [ "Command"; "make" ] [ string constructor.command_name ]
    |> with_option constructor.command_about (fun about -> command_call "about" [ string about ])
    |> with_option constructor.command_long_about (fun text -> command_call "longAbout" [ string text ])
    |> fun expression ->
    List.fold_left
      (fun e alias -> command_call "alias" [ string alias ] e)
      expression constructor.command_aliases
    |> fun expression ->
    List.fold_left
      (fun e alias -> command_call "visibleAlias" [ string alias ] e)
      expression constructor.command_visible_aliases
    |> with_flag constructor.command_hide (command_call "hide" [])
  in
  match constructor.payload with
  | No_payload -> init
  | Inline_record fields -> augment_nested init (List.filter_map augment_step fields)
  | Args_payload target -> call loc [ "Args"; "augment" ] [ generated_value Args target; init ]
  | Nested_subcommand { subcommand; optional } ->
      let name = if optional then "augment" else "augmentRequired" in
      call loc [ "Subcommand"; name ] [ generated_value Subcommand subcommand; init ]

let constructor_case (spec : Spec.t) (constructor : subcommand_constructor) =
  let loc = Ast.ghost constructor.constructor_loc in
  let build payload =
    ok loc
      (Ast.constraint_ loc
         (Ast.construct loc (lid constructor.constructor) payload)
         (self_type loc spec))
  in
  let matches = Ast.var loc matches_var in
  let wrap scrutinee =
    result_switch loc scrutinee ~ok_pattern:(Ast.pvar loc value_var)
      ~ok:(build (Some (Ast.var loc value_var)))
  in
  let used, body =
    match constructor.payload with
    | No_payload -> (false, build None)
    | Inline_record fields ->
        ( reads_matches fields,
          decode_fields loc fields ~finish:(fun values -> build (Some (Ast.record loc values))) )
    | Args_payload target ->
        (true, wrap (call loc [ "Args"; "fromMatches" ] [ generated_value Args target; matches ]))
    | Nested_subcommand { subcommand; optional } ->
        let name = if optional then "fromMatchesOptional" else "fromMatches" in
        (true, wrap (call loc [ "Subcommand"; name ] [ generated_value Subcommand subcommand; matches ]))
  in
  let pattern =
    Ast.pconstruct loc (lid "Some")
      (Some
         (Ast.ptuple loc
            [ Ast.pstring loc constructor.command_name; matches_pattern loc ~used ]))
  in
  Ast.case pattern body

let subcommand_value loc (spec : Spec.t) constructors =
  let steps =
    List.map
      (fun constructor command ->
        let loc = Ast.ghost constructor.constructor_loc in
        call loc [ "Command"; "subcommand" ] [ command; constructor_command loc constructor ])
      constructors
  in
  let fallback =
    Ast.case
      (Ast.por loc
         (Ast.pconstruct loc (lid "Some") (Some (Ast.pany loc)))
         (Ast.pconstruct loc (lid "None") None))
      (call loc [ "Matches"; "missingSubcommand" ] [ Ast.var loc matches_var ])
  in
  let decode =
    Ast.match_ loc
      (call loc [ "Matches"; "subcommand" ] [ Ast.var loc matches_var ])
      (List.map (constructor_case spec) constructors @ [ fallback ])
  in
  call loc [ "Subcommand"; "make" ]
    [
      Ast.lambda loc (Ast.pvar loc command_var) (augment_body loc steps);
      Ast.lambda loc (Ast.pvar loc matches_var) decode;
    ]

(* Value enums *)

let value_enum_value loc (spec : Spec.t) values =
  let possible_value (value : enum_value) =
    let loc = Ast.ghost value.value_loc in
    let pv_call name args expression = call loc [ "PossibleValue"; name ] (expression :: args) in
    let expression =
      call loc [ "PossibleValue"; "make" ] [ Ast.string loc value.value_name ]
      |> with_option value.value_help (fun help -> pv_call "help" [ Ast.string loc help ])
      |> fun expression ->
      List.fold_left
        (fun e alias -> pv_call "alias" [ Ast.string loc alias ] e)
        expression value.value_aliases
      |> with_flag value.value_hide (pv_call "hide" [])
    in
    Ast.tuple loc
      [
        Ast.constraint_ loc (Ast.construct loc (lid value.value_constructor) None) (self_type loc spec);
        expression;
      ]
  in
  call loc [ "ValueParser"; "enum" ] [ Ast.array loc (List.map possible_value values) ]

(* Parsers *)

let command_expression loc (command : command) =
  let command_call name value expression = call loc [ "Command"; name ] [ expression; Ast.string loc value ] in
  call loc [ "Command"; "make" ] [ Ast.string loc command.name ]
  |> with_option command.version (command_call "version")
  |> with_option command.about (command_call "about")
  |> with_option command.long_about (command_call "longAbout")
  |> with_option command.author (command_call "author")

(* Values and their types *)

let runtime_type loc kind type_name =
  let module_name =
    match (kind : Naming.kind) with
    | Args -> "Args"
    | Subcommand -> "Subcommand"
    | Value_parser -> "ValueParser"
    | Parser -> "Parser"
  in
  Ast.typ loc (Ast.longident "Clap" [ module_name; "t" ]) [ Ast.typ loc (lid type_name) [] ]

let binding loc kind (spec : Spec.t) body =
  Ast.value_binding loc (Naming.value_name kind spec.name) (runtime_type loc kind spec.name) body

let structure (spec : Spec.t) : structure_item list =
  let loc = Ast.ghost spec.loc in
  let own kind = Ast.var loc (Naming.value_name kind spec.name) in
  match spec.kind with
  | Args fields -> [ binding loc Args spec (args_value loc spec fields) ]
  | Subcommand constructors -> [ binding loc Subcommand spec (subcommand_value loc spec constructors) ]
  | Value_enum values -> [ binding loc Value_parser spec (value_enum_value loc spec values) ]
  | Parser_args (command, fields) ->
      [
        binding loc Args spec (args_value loc spec fields);
        binding loc Parser spec
          (call loc [ "Parser"; "fromArgs" ] [ command_expression loc command; own Args ]);
      ]
  | Parser_subcommand (command, constructors) ->
      [
        binding loc Subcommand spec (subcommand_value loc spec constructors);
        binding loc Parser spec
          (call loc [ "Parser"; "fromSubcommand" ] [ command_expression loc command; own Subcommand ]);
      ]

let signature loc ~type_name (kinds : Naming.kind list) : signature_item list =
  let loc = Ast.ghost loc in
  List.map
    (fun kind -> Ast.value_declaration loc (Naming.value_name kind type_name) (runtime_type loc kind type_name))
    kinds
