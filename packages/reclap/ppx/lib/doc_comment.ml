(* Doc comments to help text, following clap_derive's [format_doc_comment].

   The comment is split into lines; leading and trailing blank lines are
   dropped. Paragraphs are separated by blank lines, and the lines of a
   paragraph are trimmed and joined with spaces.

   - The summary ([about] / [help]) is the first paragraph without a single
     trailing period ("..." is kept).
   - The long text ([longAbout] / [longHelp]) exists only when there is more
     than one paragraph: every paragraph, joined by an empty line. *)

type t = { summary : string; long : string option }

let is_blank line = String.trim line = ""

let rec drop_blank = function
  | line :: rest when is_blank line -> drop_blank rest
  | lines -> lines

let paragraphs text =
  let lines = String.split_on_char '\n' text in
  let lines = List.rev (drop_blank (List.rev (drop_blank lines))) in
  let finish current acc =
    match current with
    | [] -> acc
    | _ -> String.concat " " (List.rev current) :: acc
  in
  let rec go current acc = function
    | [] -> List.rev (finish current acc)
    | line :: rest when is_blank line -> go [] (finish current acc) rest
    | line :: rest -> go (String.trim line :: current) acc rest
  in
  go [] [] lines

let remove_period text =
  let length = String.length text in
  let ends_with suffix = String.ends_with ~suffix text in
  if ends_with "." && not (ends_with "..") then String.sub text 0 (length - 1)
  else text

let parse text =
  match paragraphs text with
  | [] -> None
  | [ only ] -> Some { summary = remove_period only; long = None }
  | first :: _ as all ->
      Some
        { summary = remove_period first; long = Some (String.concat "\n\n" all) }
