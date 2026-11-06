let () =
  match Sys.argv with
  | [| _; input; output |] -> (
      match Reclap_ppx.Ast_io.read input with
      | Ok (source_name, ast) ->
          Reclap_ppx.Ast_io.write output source_name (Reclap_ppx.rewrite ~source_name ast)
      | Error (Unknown_magic magic) ->
          prerr_endline
            ("reclap-ppx: unsupported AST format " ^ magic
           ^ ". reclap supports the ReScript 12 PPX interface.");
          exit 2)
  | _ ->
      prerr_endline "Usage: reclap-ppx <input-ast> <output-ast>";
      exit 2
