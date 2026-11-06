(* The binary protocol between the ReScript compiler and a PPX executable.

   The compiler runs [ppx input output]. Both files contain a magic number, the
   source file name, and the marshalled [Parsetree0] tree. The magic number
   tells implementations (.res) from interfaces (.resi). *)

type ast =
  | Implementation of Parsetree0.structure
  | Interface of Parsetree0.signature

let implementation_magic = "Caml1999M022"
let interface_magic = "Caml1999N022"

type read_error = Unknown_magic of string

let read path =
  In_channel.with_open_bin path (fun channel ->
      let magic =
        really_input_string channel (String.length implementation_magic)
      in
      let source_name : string = input_value channel in
      if magic = implementation_magic then
        let structure : Parsetree0.structure = input_value channel in
        Ok (source_name, Implementation structure)
      else if magic = interface_magic then
        let signature : Parsetree0.signature = input_value channel in
        Ok (source_name, Interface signature)
      else Error (Unknown_magic magic))

let write path source_name ast =
  Out_channel.with_open_bin path (fun channel ->
      match ast with
      | Implementation structure ->
          output_string channel implementation_magic;
          output_value channel (source_name : string);
          output_value channel (structure : Parsetree0.structure)
      | Interface signature ->
          output_string channel interface_magic;
          output_value channel (source_name : string);
          output_value channel (signature : Parsetree0.signature))
