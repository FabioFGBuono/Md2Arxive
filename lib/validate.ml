(* ============================================================
   validate.ml
   Controlli semantici sull'AST completo.

   Mentre parser.ml controlla la sintassi riga per riga, qui
   facciamo controlli "globali" che richiedono di vedere tutto
   il documento insieme.
   
   - una citazione [@k] nel testo senza \bibitem{k}  -> errore
     (LaTeX produrrebbe "[?]");
   - una voce di bibliografia mai citata             -> warning.
   ============================================================ *)

open Ast

(* Raccoglie tutte le chiavi citate (Cite) scorrendo gli inline. *)
let cited_keys (blocks : block list) : string list =
  let from_inlines inls =
    List.filter_map (function Cite k -> Some k | _ -> None) inls
  in
  List.concat_map (function
    | Paragraph inls        -> from_inlines inls
    | Heading (_, inls)     -> from_inlines inls
    | UnorderedList items   -> List.concat_map from_inlines items
    | _                     -> []
  ) blocks

(* Raccoglie le chiavi definite nella bibliografia. *)
let defined_keys (blocks : block list) : string list =
  List.concat_map (function
    | Bibliography entries -> List.map fst entries
    | _ -> []
  ) blocks

(* run : Diag.t -> block list -> unit
   Controlli semantici globali sulle citazioni.
   @ensures  per ogni chiave k citata ma non definita -> un Diag.error
   @ensures  per ogni chiave k definita ma non citata -> un Diag.warn
   @ensures  un documento con citazioni e bibliografia coerenti non
             produce alcun diagnostico da questo modulo
   @note     non modifica i block; ha solo l'effetto di popolare diag. *)
let run (diag : Diag.t) (blocks : block list) : unit =
  let cited   = cited_keys blocks in
  let defined = defined_keys blocks in

  (* citazioni senza voce: errore *)
  List.iter (fun k ->
    if not (List.mem k defined) then
      Diag.error diag ~phase:"validate"
        (Printf.sprintf
           "citazione [@%s] senza voce corrispondente in ## Bibliografia" k)
  ) (List.sort_uniq compare cited);

  (* voci mai citate: warning *)
  List.iter (fun k ->
    if not (List.mem k cited) then
      Diag.warn diag ~phase:"validate"
        (Printf.sprintf "voce bibliografica [@%s] definita ma mai citata" k)
  ) (List.sort_uniq compare defined)
