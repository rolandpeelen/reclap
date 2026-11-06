(* Rewrites one type declaration group: analyses the annotated declarations,
   removes the consumed attributes, and appends the generated values (or the
   errors) after the whole group, so mutually recursive groups work. *)

open Parsetree0

type classified = {
  declaration : type_declaration;
  errors : Diagnostic.collector;
  classification : Analyze.classification;
}

let classify declarations =
  List.map
    (fun declaration ->
      let errors = Diagnostic.collector () in
      { declaration; errors; classification = Analyze.classify errors declaration.ptype_attributes })
    declarations

let untouched classified =
  List.for_all (fun c -> c.classification = Analyze.Plain) classified

let stripped classified =
  List.map
    (fun c ->
      match c.classification with
      | Plain -> c.declaration
      | Derive _ | Invalid -> Analyze.strip c.declaration)
    classified

(* Orders the specs so every generated value comes after the values of the
   same group that it uses. Cycles are reported: generated values are not
   functions, so they cannot be recursive. *)
let order errors (specs : Spec.t list) =
  let owner name =
    List.find_opt (fun (spec : Spec.t) -> List.mem name (Spec.generated_names spec)) specs
  in
  let dependencies spec =
    List.filter_map
      (fun name -> Option.map (fun (owner : Spec.t) -> owner.name) (owner name))
      (Spec.local_dependencies spec)
  in
  let rec go emitted remaining =
    match remaining with
    | [] -> List.rev emitted
    | first :: _ -> (
        let ready (spec : Spec.t) =
          List.for_all
            (fun name -> List.exists (fun (done_ : Spec.t) -> done_.name = name) emitted)
            (dependencies spec)
        in
        match List.find_opt ready remaining with
        | Some spec -> go (spec :: emitted) (List.filter (fun other -> other != spec) remaining)
        | None ->
            Diagnostic.reportf errors first.loc
              "These @clap types depend on each other: %s. Recursive @clap types \
               are not supported."
              (String.concat ", " (List.map (fun (spec : Spec.t) -> spec.name) remaining));
            List.rev emitted)
  in
  go [] specs

let all_errors classified = List.concat_map (fun c -> Diagnostic.to_list c.errors) classified

let structure ~module_name (item : structure_item) rec_flag declarations =
  let classified = classify declarations in
  if untouched classified then [ item ]
  else
    let specs =
      List.filter_map
        (fun c ->
          match c.classification with
          | Plain | Invalid -> None
          | Derive derive -> Analyze.analyze c.errors ~module_name derive c.declaration)
        classified
    in
    let order_errors = Diagnostic.collector () in
    let ordered =
      match all_errors classified with [] -> order order_errors specs | _ :: _ -> []
    in
    let rewritten = { item with pstr_desc = Pstr_type (rec_flag, stripped classified) } in
    match all_errors classified @ Diagnostic.to_list order_errors with
    | [] -> rewritten :: List.concat_map Codegen.structure ordered
    | errors ->
        rewritten
        :: List.map
             (fun (error : Diagnostic.t) -> Ast.structure_error error.loc error.message)
             errors

let signature (item : signature_item) rec_flag declarations =
  let classified = classify declarations in
  if untouched classified then [ item ]
  else
    let generated =
      List.concat_map
        (fun c ->
          match c.classification with
          | Plain | Invalid -> []
          | Derive derive -> (
              match Analyze.analyze_signature c.errors derive c.declaration with
              | None -> []
              | Some kinds ->
                  Codegen.signature c.declaration.ptype_loc
                    ~type_name:c.declaration.ptype_name.txt kinds))
        classified
    in
    let rewritten = { item with psig_desc = Psig_type (rec_flag, stripped classified) } in
    match all_errors classified with
    | [] -> rewritten :: generated
    | errors ->
        rewritten
        :: List.map
             (fun (error : Diagnostic.t) -> Ast.signature_error error.loc error.message)
             errors
