(* Doc comments to help text, following clap_derive's [format_doc_comment].

   JSDoc [*] line prefixes are removed first (see [strip_star_prefixes]).
   The comment is split into lines; leading and trailing blank lines are
   dropped. Paragraphs are separated by blank lines, and the lines of a
   paragraph are trimmed and joined with spaces.

   - The summary ([about] / [help]) is the first paragraph without a single
     trailing period ("..." is kept).
   - The long text ([longAbout] / [longHelp]) exists only when there is more
     than one paragraph: every paragraph, joined by an empty line. *)

type t = { summary : string; long : string option }

let is_blank line = String.trim line = ""

(* JSDoc style comments start their lines with [*]:

   {v
   /**
    * Summary.
    *
    * More.
    */
   v}

   When every non-blank line after the first starts with [*] (after
   indentation), the [*] and one following space are removed from every line
   that has them, the first line included. A comment whose later lines do not
   all start with [*] is left alone, so a Markdown list item keeps its [*]. *)
let strip_star_prefixes text =
  let star_prefix_length line =
    let length = String.length line in
    let rec indentation index =
      if index < length && (line.[index] = ' ' || line.[index] = '\t') then indentation (index + 1)
      else index
    in
    let star = indentation 0 in
    if star < length && line.[star] = '*' then
      Some (if star + 1 < length && line.[star + 1] = ' ' then star + 2 else star + 1)
    else None
  in
  let strip line =
    match star_prefix_length line with
    | Some prefix -> String.sub line prefix (String.length line - prefix)
    | None -> line
  in
  match String.split_on_char '\n' text with
  | [] -> text
  | first :: rest ->
      let starred line = is_blank line || star_prefix_length line <> None in
      if rest <> [] && List.exists (fun line -> not (is_blank line)) rest && List.for_all starred rest
      then String.concat "\n" (List.map strip (first :: rest))
      else text

let rec drop_blank = function
  | line :: rest when is_blank line -> drop_blank rest
  | lines -> lines

let paragraphs text =
  let lines = String.split_on_char '\n' (strip_star_prefixes text) in
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
