(* Builders for the [Parsetree0] nodes that the PPX generates.

   The shapes follow what the ReScript parser produces for the same source:
   one-parameter lambdas are [Function$] constructors with a [res.arity]
   attribute around a [Pexp_fun], and string constants carry the ["js"]
   delimiter. *)

open Parsetree0

let ghost (loc : Location.t) = { loc with loc_ghost = true }
let mkloc loc txt : _ Location.loc = { txt; loc }

(* [longident "Clap" ["Arg"; "make"]] is [Clap.Arg.make]. *)
let longident first rest =
  List.fold_left
    (fun path name -> Longident.Ldot (path, name))
    (Longident.Lident first) rest

(* Expressions *)

let exp ?(attrs = []) loc desc =
  { pexp_desc = desc; pexp_loc = loc; pexp_attributes = attrs }

let ident loc lid = exp loc (Pexp_ident (mkloc loc lid))
let var loc name = ident loc (Lident name)

(* [Clap.Arg.make] and friends. *)
let clap loc path = ident loc (longident "Clap" path)
let string loc s = exp loc (Pexp_constant (Pconst_string (s, Some "js")))
let bool loc b = exp loc (Pexp_construct (mkloc loc (Longident.Lident (string_of_bool b)), None))

let apply loc f args =
  exp loc (Pexp_apply (f, List.map (fun arg -> (Asttypes.Noloc.Nolabel, arg)) args))

let construct loc lid arg = exp loc (Pexp_construct (mkloc loc lid, arg))
let tuple loc items = exp loc (Pexp_tuple items)
let array loc items = exp loc (Pexp_array items)

let record loc fields =
  exp loc
    (Pexp_record
       (List.map (fun (name, value) -> (mkloc loc (Longident.Lident name), value)) fields, None))

let constraint_ loc e typ = exp loc (Pexp_constraint (e, typ))

let arity_attribute loc arity : attribute =
  ( mkloc loc "res.arity",
    PStr
      [
        {
          pstr_desc =
            Pstr_eval (exp loc (Pexp_constant (Pconst_integer (string_of_int arity, None))), []);
          pstr_loc = loc;
        };
      ] )

(* [param => body] *)
let lambda loc (param : pattern) body =
  let fn = exp loc (Pexp_fun (Nolabel, None, param, body)) in
  exp ~attrs:[ arity_attribute loc 1 ] loc
    (Pexp_construct (mkloc loc (Longident.Lident "Function$"), Some fn))

let let_ loc (pattern : pattern) value body =
  exp loc
    (Pexp_let
       (Nonrecursive, [ { pvb_pat = pattern; pvb_expr = value; pvb_attributes = []; pvb_loc = loc } ], body))

let case lhs rhs = { pc_lhs = lhs; pc_guard = None; pc_rhs = rhs }
let match_ loc scrutinee cases = exp loc (Pexp_match (scrutinee, cases))

let error_extension loc message : extension =
  ( mkloc loc "ocaml.error",
    (* No "js" delimiter: the compiler would escape the quotes in the message. *)
    PStr
      [
        {
          pstr_desc = Pstr_eval (exp loc (Pexp_constant (Pconst_string (message, None))), []);
          pstr_loc = loc;
        };
      ] )

(* Patterns *)

let pat loc desc = { ppat_desc = desc; ppat_loc = loc; ppat_attributes = [] }
let pvar loc name = pat loc (Ppat_var (mkloc loc name))
let pany loc = pat loc Ppat_any
let pstring loc s = pat loc (Ppat_constant (Pconst_string (s, Some "js")))
let pconstruct loc lid arg = pat loc (Ppat_construct (mkloc loc lid, arg))
let ptuple loc items = pat loc (Ppat_tuple items)
let por loc a b = pat loc (Ppat_or (a, b))
let pconstraint loc p typ = pat loc (Ppat_constraint (p, typ))

(* Types *)

let typ loc lid args =
  { ptyp_desc = Ptyp_constr (mkloc loc lid, args); ptyp_loc = loc; ptyp_attributes = [] }

(* Structure and signature items *)

let value_binding loc name typ body : structure_item =
  {
    pstr_desc =
      Pstr_value
        ( Nonrecursive,
          [
            {
              pvb_pat = pconstraint loc (pvar loc name) typ;
              pvb_expr = body;
              pvb_attributes = [];
              pvb_loc = loc;
            };
          ] );
    pstr_loc = loc;
  }

let value_declaration loc name typ : signature_item =
  {
    psig_desc =
      Psig_value
        { pval_name = mkloc loc name; pval_type = typ; pval_prim = []; pval_attributes = []; pval_loc = loc };
    psig_loc = loc;
  }

let structure_error loc message : structure_item =
  { pstr_desc = Pstr_extension (error_extension loc message, []); pstr_loc = loc }

let signature_error loc message : signature_item =
  { psig_desc = Psig_extension (error_extension loc message, []); psig_loc = loc }
