(* ============================================================
   ast.ml
   La sintassi astratta.

   Questo modulo definisce SOLO tipi, è il "contratto" che lexer, parser ed emit rispettano.

   Riferimento teorico:
     G. Levi, Linguaggi di Programmazione (Unipi)
     "definisci la semantica come funzione sull'albero".
     Real World OCaml, cap. 6 (Variants).
   ============================================================ *)


(* ---------- Livello INLINE ----------
   Elementi che vivono dentro una riga di testo.
   Ogni costruttore corrisponde a un costrutto Markdown. *)
type inline =
  | Text   of string            (* testo grezzo                 *)
  | Bold   of string            (* **grassetto**                *)
  | Italic of string            (* *corsivo*                    *)
  | Code   of string            (* `codice inline`              *)
  | Cite   of string            (* [@chiave]  -> \cite{chiave}  *)
  | Link   of string * string   (* [testo](url)                 *)


(* ---------- Livello BLOCK ----------
   Elementi strutturali. Una lista di block È il documento. *)
type block =
  | Heading       of int * inline list          (* livello #, contenuto       *)
  | Paragraph     of inline list
  | UnorderedList of inline list list           (* ogni item è una riga inline *)
  | CodeBlock     of string                      (* blocco ``` ... ```          *)
  | Image         of string * string            (* alt, path                   *)
  | Table         of string list * string list list  (* header, righe          *)
  | Bibliography  of (string * string) list      (* (chiave, descrizione)      *)


(* ---------- METADATI (frontmatter YAML) ----------
   Non è parte del corpo del documento ma del suo "header".
   Serve a generare \title, \author, \affiliation per arXiv. *)
type author = {
  name  : string;
  affil : string;
  orcid : string option;        (* 0000-0000-0000-000X *)
  email : string option;
}

type meta = {
  title    : string;
  authors  : author list;
  abstract : string;
  keywords : string list;
  category : string;            (* es. cs.LG, math.OC *)
  date     : string;
}

(* Un documento completo: metadati + corpo. *)
type document = {
  meta   : meta;
  blocks : block list;
}
