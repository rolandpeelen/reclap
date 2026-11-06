(* User-facing errors, reported as [%%ocaml.error] items at their location. *)

type t = { loc : Parsetree0.Location.t; message : string }

(* Errors found while analysing one type declaration group, newest first. *)
type collector = t list ref

let collector () : collector = ref []
let report (errors : collector) loc message = errors := { loc; message } :: !errors
let reportf errors loc fmt = Printf.ksprintf (report errors loc) fmt
let to_list (errors : collector) = List.rev !errors
