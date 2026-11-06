(* Prints the results of the pure modules; dune diffs the output with
   test_reclap_ppx.expected. *)

open Reclap_ppx

let section title = Printf.printf "\n## %s\n" title
let quote text = "\"" ^ String.escaped text ^ "\""

let casing () =
  section "Casing.convert";
  let inputs =
    [ "fooBar"; "FooBar"; "configFile"; "HTTPServer"; "parseHTTP2Response"; "dry_run";
      "already-kebab"; "x"; "a1B"; "AutoDetect"; "JsonLines"; "IO" ]
  in
  List.iter
    (fun (style_name, style) ->
      Printf.printf "%-22s" style_name;
      List.iter (fun input -> Printf.printf " %s" (Casing.convert style input)) inputs;
      print_newline ())
    Casing.all;
  Printf.printf "words HTTPServer: [%s]\n" (String.concat "; " (Casing.words "HTTPServer"));
  Printf.printf "of_string \"Kebab\": %b\n" (Casing.of_string "Kebab" = None)

let doc_comment () =
  section "Doc_comment.parse";
  let show text =
    match Doc_comment.parse text with
    | None -> Printf.printf "%s -> None\n" (quote text)
    | Some { summary; long } ->
        Printf.printf "%s ->\n  summary %s\n  long    %s\n" (quote text) (quote summary)
          (match long with None -> "None" | Some long -> quote long)
  in
  List.iter show
    [
      " Name of the person to greet ";
      " Ends with a period. ";
      " Ends with an ellipsis... ";
      " Two lines\n  joined with a space. ";
      " Summary.\n\n  Second paragraph\n  over two lines.\n\n  Third. ";
      "\n  Leading and trailing blank lines \n\n";
      "   ";
      "";
    ]

let naming () =
  section "Naming";
  List.iter
    (fun (kind, type_name) ->
      Printf.printf "%s %s -> %s\n" (Naming.suffix kind) type_name (Naming.value_name kind type_name))
    [ (Naming.Args, "t"); (Args, "addArgs"); (Subcommand, "t"); (Subcommand, "command");
      (Value_parser, "t"); (Value_parser, "level"); (Parser, "t"); (Parser, "tool") ];
  let rec path : Parsetree0.Longident.t -> string = function
    | Lident name -> name
    | Ldot (prefix, name) -> path prefix ^ "." ^ name
    | Lapply (f, x) -> path f ^ "(" ^ path x ^ ")"
  in
  Printf.printf "Git.remote subcommand -> %s\n"
    (path (Naming.value_path Subcommand ~module_path:(Some (Lident "Git")) "remote"));
  Printf.printf "Level.t value parser -> %s\n"
    (path (Naming.value_path Value_parser ~module_path:(Some (Lident "Level")) "t"));
  List.iter
    (fun source -> Printf.printf "module of %s -> %s\n" source (Naming.module_of_source source))
    [ "Greet.res"; "test/ppx/GitLike.res"; "Api.resi"; "/abs/path/Foo.bar.res" ];
  Printf.printf "command name of GitLike.t -> %s\n" (Naming.command_name ~module_name:"GitLike" "t");
  Printf.printf "command name of myTool -> %s\n" (Naming.command_name ~module_name:"GitLike" "myTool")

let () =
  casing ();
  doc_comment ();
  naming ()
