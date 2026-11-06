module Parsetree0 = Parsetree0
module Ast_io = Ast_io

let rewrite (ast : Ast_io.ast) : Ast_io.ast =
  match ast with
  | Implementation structure ->
      let open Parsetree0 in
      let loc = Location.none in
      let probe =
        {
          pstr_loc = loc;
          pstr_desc =
            Pstr_value
              ( Nonrecursive,
                [
                  {
                    pvb_pat =
                      { ppat_desc = Ppat_var { txt = "__reclap_probe"; loc }; ppat_loc = loc; ppat_attributes = [] };
                    pvb_expr =
                      { pexp_desc = Pexp_constant (Pconst_string ("hello", Some "js")); pexp_loc = loc; pexp_attributes = [] };
                    pvb_attributes = [];
                    pvb_loc = loc;
                  };
                ] );
        }
      in
      Implementation (probe :: structure)
  | Interface _ -> ast
