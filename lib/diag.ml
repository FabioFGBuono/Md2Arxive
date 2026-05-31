(* ============================================================
   diag.ml 
   Raccolta diagnostica (warning ed errori)
   ============================================================ *)

type severity = Warning | Error

type item = {
  severity : severity;
  line     : int option;   (* riga 1-based, None se non localizzabile *)
  phase    : string;       (* "meta" | "parser" | "package" ...        *)
  message  : string;
}

(* Il collector: una lista mutabile in ordine inverso di inserimento.
   @invariant  items contiene i diagnostici in ordine INVERSO di
               inserimento; `all` ripristina l'ordine cronologico. *)
type t = { mutable items : item list }

let create () : t = { items = [] }

(* add : t -> ?line:int -> phase:string -> severity -> string -> unit
   @ensures  dopo la chiamata, |t.items| è cresciuto di 1
   @ensures  il nuovo item è in TESTA a t.items (ordine inverso) *)
let add t ?line ~phase severity message =
  t.items <- { severity; line; phase; message } :: t.items

(* scorciatoie *)
let warn t ?line ~phase msg = add t ?line ~phase Warning msg
let error t ?line ~phase msg = add t ?line ~phase Error msg

(* Diagnostici in ordine cronologico. *)
let all t = List.rev t.items

let has_errors t =
  List.exists (fun i -> i.severity = Error) t.items

let count t =
  List.fold_left
    (fun (w, e) i -> match i.severity with
       | Warning -> (w + 1, e)
       | Error   -> (w, e + 1))
    (0, 0) t.items

(* Formattazione leggibile, stile compilatore:
     paper.md:12: error [parser]: ...
     paper.md:30: warning [package]: ... *)
let string_of_item ~source i =
  let sev = match i.severity with Warning -> "warning" | Error -> "error" in
  let loc = match i.line with
    | Some n -> Printf.sprintf "%s:%d" source n
    | None   -> source
  in
  Printf.sprintf "%s: %s [%s]: %s" loc sev i.phase i.message

(* Stampa tutti i diagnostici su stderr e un riepilogo finale.
   Ritorna true se ci sono errori (per decidere l'exit code). *)
let report t ~source =
  List.iter (fun i -> Printf.eprintf "%s\n" (string_of_item ~source i)) (all t);
  let (w, e) = count t in
  if w > 0 || e > 0 then
    Printf.eprintf "%d warning, %d errori\n" w e;
  e > 0
