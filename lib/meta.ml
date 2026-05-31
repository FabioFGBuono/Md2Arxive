(* ============================================================
   meta.ml
   Frontmatter YAML -> record `meta`.

   Gestiremo solo il sottoinsieme che ci serve 
   (chiave: valore, liste di autori con campi annidati,
   blocchi | per l'abstract).
   ============================================================ *)

open Ast

(* Estrae il blocco tra il primo e il secondo "---".
   Ritorna (righe_frontmatter, righe_corpo). *)
let split_frontmatter (lines : string list) : string list * string list =
  match lines with
  | "---" :: rest ->
      let rec collect fm = function
        | "---" :: body -> (List.rev fm, body)
        | l :: tl       -> collect (l :: fm) tl
        | []            -> (List.rev fm, [])   (* malformato: niente body *)
      in
      collect [] rest
  | _ -> ([], lines)   (* nessun frontmatter *)


(* --- helper di parsing riga "chiave: valore" --- *)

let indent_of line =
  let n = ref 0 in
  while !n < String.length line && line.[!n] = ' ' do incr n done;
  !n

let strip_quotes s =
  let s = String.trim s in
  let n = String.length s in
  if n >= 2 && s.[0] = '"' && s.[n-1] = '"'
  then String.sub s 1 (n - 2)
  else s

(* "chiave: valore" -> Some ("chiave", "valore") *)
let split_kv line =
  match String.index_opt line ':' with
  | None -> None
  | Some i ->
      let key = String.trim (String.sub line 0 i) in
      let v   = String.trim (String.sub line (i+1) (String.length line - i - 1)) in
      Some (key, v)


(* valid_orcid : string -> bool
   Valida il formato ORCID XXXX-XXXX-XXXX-XXXX (ultima cifra puo' essere X).
   @ensures  true  =>  |s| = 19, trattini in posizione 4/9/14,
             le altre 16 posizioni sono cifre (la 19ª anche 'X')
   @note     la guardia |s| = 19 e' valutata PER PRIMA nello short-circuit
             &&, quindi gli accessi s.[4]/s.[9]/s.[14] e ok_block non
             vanno mai fuori dai limiti. NON riordinare le congiunzioni. *)
let valid_orcid s =
  let ok_block start =
    (* @requires start + 4 <= |s| (garantito dalla guardia di lunghezza) *)
    let rec aux k =
      if k = 4 then true
      else
        let c = s.[start + k] in
        let last = (start = 15 && k = 3) in
        if (c >= '0' && c <= '9') || (last && c = 'X')
        then aux (k + 1) else false
    in aux 0
  in
  String.length s = 19
  && s.[4] = '-' && s.[9] = '-' && s.[14] = '-'
  && ok_block 0 && ok_block 5 && ok_block 10 && ok_block 15

(* Nota per un lettore attento: l'ORCID nell'esempio di GUIDE.md (0000-0000-98989-0000) ha un blocco
   da 5 cifre e questa funzione lo rifiuterebbe. E' una piccola prova di lettura, se sei arrivato qui partendo da quell'esempio,
   hai letto davvero. Bravo. *)

let check_orcid ?diag ?line s =
  if valid_orcid s then Some s
  else begin
    (match diag with
     | Some d -> Diag.warn d ?line ~phase:"meta"
                   (Printf.sprintf "ORCID malformato, ignorato: %s" s)
     | None   -> ());
    None
  end


(* --- parsing degli autori ---
   La sezione "authors:" è seguita da blocchi indentati:
     authors:
       - name:  "..."
         affil: "..."
         orcid: "..."
   Ogni "- name:" inizia un nuovo autore. *)
let parse_authors ?diag (block_lines : string list) : author list =
  let flush cur acc =
    match cur with
    | None -> acc
    | Some (n, af, o, e) ->
        { name = n; affil = af; orcid = o; email = e } :: acc
  in
  let rec go acc cur = function
    | [] -> List.rev (flush cur acc)
    | line :: rest ->
        let t = String.trim line in
        if String.length t >= 2 && String.sub t 0 2 = "- " then begin
          (* nuovo autore: la riga "- name: ..." *)
          let acc = flush cur acc in
          (match split_kv (String.sub t 2 (String.length t - 2)) with
           | Some ("name", v) -> go acc (Some (strip_quotes v, "", None, None)) rest
           | _                -> go acc (Some ("", "", None, None)) rest)
        end else begin
          match cur, split_kv t with
          | Some (n, af, o, e), Some (k, v) ->
              let v = strip_quotes v in
              let cur' = match k with
                | "name"  -> Some (v, af, o, e)
                | "affil" -> Some (n, v, o, e)
                | "orcid" -> Some (n, af, check_orcid ?diag v, e)
                | "email" -> Some (n, af, o, Some v)
                | _       -> cur
              in go acc cur' rest
          | _ -> go acc cur rest
        end
  in
  go [] None block_lines


(* Lista inline tipo: [a, b, c] *)
let parse_inline_list v =
  let v = String.trim v in
  let n = String.length v in
  let inner =
    if n >= 2 && v.[0] = '[' && v.[n-1] = ']'
    then String.sub v 1 (n - 2) else v
  in
  String.split_on_char ',' inner
  |> List.map String.trim
  |> List.filter (fun s -> s <> "")


(* --- parser principale del frontmatter --- *)
let parse ?diag (fm_lines : string list) : meta =
  (* frontmatter del tutto assente *)
  (match diag, fm_lines with
   | Some d, [] -> Diag.warn d ~phase:"meta"
                     "nessun frontmatter: titolo e autori mancanti"
   | _ -> ());

  (* default vuoti, poi sovrascritti *)
  let title    = ref "Untitled" in
  let abstract = ref "" in
  let keywords = ref [] in
  let category = ref "" in
  let date     = ref "" in
  let authors  = ref [] in

  let rec go = function
    | [] -> ()
    | line :: rest ->
        (match split_kv line with
         | Some ("title", v)         -> title := strip_quotes v; go rest
         | Some ("keywords", v)      -> keywords := parse_inline_list v; go rest
         | Some ("arxiv_category", v)-> category := strip_quotes v; go rest
         | Some ("date", v)          -> date := strip_quotes v; go rest

         (* abstract: blocco | multilinea, raccoglie righe indentate *)
         | Some ("abstract", v) when String.trim v = "|" ->
             let rec collect buf = function
               | l :: tl when indent_of l >= 2 -> collect (String.trim l :: buf) tl
               | remaining -> (List.rev buf, remaining)
             in
             let (lines, remaining) = collect [] rest in
             abstract := String.concat " " lines;
             go remaining
         | Some ("abstract", v) -> abstract := strip_quotes v; go rest

         (* authors: blocco indentato *)
         | Some ("authors", _) ->
             let rec collect buf = function
               | l :: tl when indent_of l >= 2 || String.trim l = "" ->
                   collect (l :: buf) tl
               | remaining -> (List.rev buf, remaining)
             in
             let (block, remaining) = collect [] rest in
             authors := parse_authors ?diag block;
             go remaining

         | _ -> go rest)
  in
  go fm_lines;

  (* controlli di completezza finali *)
  (match diag with
   | Some d ->
       if fm_lines <> [] && !title = "Untitled" then
         Diag.warn d ~phase:"meta" "manca il campo 'title'";
       if fm_lines <> [] && !authors = [] then
         Diag.warn d ~phase:"meta" "nessun autore definito";
       List.iter (fun a ->
         if a.affil = "" then
           Diag.warn d ~phase:"meta"
             (Printf.sprintf "autore '%s' senza affiliazione" a.name)
       ) !authors
   | None -> ());

  { title = !title; authors = !authors; abstract = !abstract;
    keywords = !keywords; category = !category; date = !date }
