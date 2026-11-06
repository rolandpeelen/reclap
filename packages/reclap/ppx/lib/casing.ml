(* Case conversion for [renameAll], following clap (which uses the [heck]
   crate). Words are split at non-alphanumeric characters, before an uppercase
   letter that follows a lowercase letter or digit, and before the last letter
   of an uppercase run that is followed by a lowercase letter ("HTTPServer" is
   "HTTP" + "Server"). Only ASCII letters have a case. *)

type t =
  | Kebab
  | Snake
  | Camel
  | Pascal
  | Screaming_snake
  | Lower
  | Upper
  | Verbatim

let all =
  [
    ("kebab-case", Kebab);
    ("snake_case", Snake);
    ("camelCase", Camel);
    ("PascalCase", Pascal);
    ("SCREAMING_SNAKE_CASE", Screaming_snake);
    ("lower", Lower);
    ("UPPER", Upper);
    ("verbatim", Verbatim);
  ]

let of_string name = List.assoc_opt name all
let is_upper c = c >= 'A' && c <= 'Z'
let is_lower c = c >= 'a' && c <= 'z'
let is_digit c = c >= '0' && c <= '9'
let is_alnum c = is_upper c || is_lower c || is_digit c || Char.code c >= 128

type mode = Lowercase | Uppercase | Boundary

(* Splits one run of alphanumeric characters into words. *)
let split_run run =
  let length = String.length run in
  let words = ref [] in
  let start = ref 0 in
  let cut stop =
    if stop > !start then words := String.sub run !start (stop - !start) :: !words;
    start := stop
  in
  let mode = ref Boundary in
  for i = 0 to length - 1 do
    let c = run.[i] in
    let next_mode =
      if is_lower c then Lowercase else if is_upper c then Uppercase else !mode
    in
    (if i + 1 < length then
       let next = run.[i + 1] in
       if next_mode = Lowercase && is_upper next then cut (i + 1)
       else if !mode = Uppercase && is_upper c && is_lower next then cut i);
    mode := next_mode
  done;
  cut length;
  List.rev !words

let words name =
  let runs = ref [] in
  let buffer = Buffer.create 16 in
  let flush () =
    if Buffer.length buffer > 0 then (
      runs := Buffer.contents buffer :: !runs;
      Buffer.clear buffer)
  in
  String.iter (fun c -> if is_alnum c then Buffer.add_char buffer c else flush ()) name;
  flush ();
  List.concat_map split_run (List.rev !runs)

let capitalize word = String.capitalize_ascii (String.lowercase_ascii word)

let convert style name =
  match style with
  | Kebab -> String.concat "-" (List.map String.lowercase_ascii (words name))
  | Snake -> String.concat "_" (List.map String.lowercase_ascii (words name))
  | Screaming_snake ->
      String.concat "_" (List.map String.uppercase_ascii (words name))
  | Pascal -> String.concat "" (List.map capitalize (words name))
  | Camel -> (
      match words name with
      | [] -> ""
      | first :: rest ->
          String.concat ""
            (String.lowercase_ascii first :: List.map capitalize rest))
  | Lower -> String.lowercase_ascii name
  | Upper -> String.uppercase_ascii name
  | Verbatim -> name
