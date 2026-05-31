(* ============================================================
   arxiv.ml
   Generazione del documento arXiv-ready.

   Questa è la parte che distingue md2arxiv da un md->tex generico.
   ============================================================ *)

open Ast

(* Pacchetti del preamble. (nome, opzioni) *)
let packages = [
  "inputenc",  "utf8";
  "fontenc",   "T1";
  "amsmath",   "";
  "amssymb",   "";
  "graphicx",  "";
  "booktabs",  "";      (* \toprule \midrule \bottomrule *)
  "hyperref",  "";
  "orcidlink", "";      (* \orcidlink{...} *)
  "natbib",    "";
]

let emit_package (name, opts) =
  if opts = "" then "\\usepackage{" ^ name ^ "}\n"
  else "\\usepackage[" ^ opts ^ "]{" ^ name ^ "}\n"

(* Un autore: nome + (eventuale) link ORCID, su riga \author.
   In article standard gli autori vanno in un solo \author separati
   da \and; qui generiamo una riga per autore con affiliazione in nota. *)
let emit_author (a : author) : string =
  let orcid = match a.orcid with
    | Some o -> "\\,\\orcidlink{" ^ o ^ "}"
    | None   -> ""
  in
  Emit.escape a.name ^ orcid
  ^ "\\thanks{" ^ Emit.escape a.affil
  ^ (match a.email with
     | Some e -> ". \\texttt{" ^ Emit.escape e ^ "}"
     | None   -> "")
  ^ "}"

let emit_authors (authors : author list) : string =
  "\\author{"
  ^ String.concat " \\and " (List.map emit_author authors)
  ^ "}\n"

(* Il preamble completo. *)
let preamble (m : meta) : string =
  "\\documentclass[11pt]{article}\n"
  ^ String.concat "" (List.map emit_package packages)
  ^ (if m.keywords <> []
     then "% keywords: " ^ String.concat ", " m.keywords ^ "\n"
     else "")
  ^ (if m.category <> ""
     then "% arXiv category: " ^ m.category ^ "\n"
     else "")
  ^ "\n\\title{" ^ Emit.escape m.title ^ "}\n"
  ^ emit_authors m.authors
  ^ (if m.date <> "" then "\\date{" ^ Emit.escape m.date ^ "}\n" else "\\date{\\today}\n")
  ^ "\n\\begin{document}\n"
  ^ "\\maketitle\n\n"
  ^ (if m.abstract <> ""
     then "\\begin{abstract}\n" ^ Emit.escape m.abstract ^ "\n\\end{abstract}\n\n"
     else "")

let ending = "\n\\end{document}\n"

(* Documento completo: preamble + corpo + chiusura. *)
let emit_document (doc : document) : string =
  preamble doc.meta
  ^ Emit.emit_body doc.blocks
  ^ ending
