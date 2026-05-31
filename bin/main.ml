(* ============================================================
   main.ml
   Entry point, CLI e orchestrazione della diagnostica.

   Uso:
     md2arxiv < input.md > paper.tex
     md2arxiv input.md -o paper.tex
     md2arxiv input.md --package submission
     md2arxiv input.md --strict      (i warning diventano fatali)

   La pipeline crea UN collector Diag.t e lo passa a ogni fase.
   Alla fine i diagnostici vengono riportati su stderr e l'exit
   code riflette la presenza di errori (o di warning in --strict).
   ============================================================ *)

open Md2arxiv

(* Legge tutte le righe da un canale. *)
let read_all ic =
  let rec go acc =
    match input_line ic with
    | line -> go (line :: acc)
    | exception End_of_file -> List.rev acc
  in go []

let () =
  let args = Array.to_list Sys.argv |> List.tl in
  let infile  = ref None in
  let outfile = ref None in
  let pkgdir  = ref None in
  let strict  = ref false in
  let rec parse_args = function
    | [] -> ()
    | "-o" :: f :: rest        -> outfile := Some f; parse_args rest
    | "--package" :: d :: rest -> pkgdir := Some d; parse_args rest
    | "--strict" :: rest       -> strict := true; parse_args rest
    | f :: rest                -> infile := Some f; parse_args rest
  in
  parse_args args;

  let source = match !infile with Some f -> f | None -> "<stdin>" in

  let lines =
    match !infile with
    | Some f -> let ic = (try open_in f
                         with Sys_error msg ->
                           Printf.eprintf "%s\n" msg; exit 1) in
                let ls = read_all ic in close_in ic; ls
    | None   -> read_all stdin
  in

  let src_dir =
    match !infile with
    | Some f -> Filename.dirname f
    | None   -> Filename.current_dir_name
  in

  (* UN collector per tutta la pipeline. *)
  let diag = Diag.create () in

  let (fm, body) = Meta.split_frontmatter lines in
  let meta   = Meta.parse ~diag fm in
  let blocks = Parser.parse_lines diag body in
  Validate.run diag blocks;
  let doc = { meta; blocks } in

  (* Produzione output (anche in presenza di warning). *)
  (match !pkgdir with
   | Some dir -> Package.build ~diag ~doc ~src_dir ~out_dir:dir
   | None ->
       let latex = Arxiv.emit_document doc in
       (match !outfile with
        | Some f -> let oc = (try open_out f
                             with Sys_error msg ->
                               Printf.eprintf "%s\n" msg; exit 1) in
                    output_string oc latex; close_out oc;
                    Printf.eprintf "Scritto: %s\n" f
        | None   -> print_string latex));

  (* Report finale e decisione sull'exit code. *)
  let has_err = Diag.report diag ~source in
  let (w, _) = Diag.count diag in
  if has_err then exit 1
  else if !strict && w > 0 then begin
    Printf.eprintf "--strict: %d warning trattati come errori\n" w;
    exit 1
  end
