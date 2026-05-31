(* ============================================================
   parser.ml
   Analisi dei blocchi, riga per riga.

   Riferimento di studio: Levi, semantica operazionale; il contesto è
   lo "stato" di una piccola macchina che consuma righe.
   ============================================================ *)

open Ast

(* Lo stato del parser mentre consuma le righe. *)
type context =
  | Normal
  | InList  of inline list list          (* item accumulati (rovesci) *)
  | InBib   of (string * string) list     (* voci bibliografia          *)
  | InCode  of string list                 (* righe del blocco ``` ```   *)
  | InTable of int * string list list      (* riga d'apertura, righe     *)


(* ---------- riconoscitori di riga (predicati puri) ---------- *)

let is_fence line =
  String.length line >= 3 && String.sub line 0 3 = "```"

let is_list_item line =
  String.length line > 2 && String.sub line 0 2 = "- "

let is_table_row line =
  String.length line > 0 && line.[0] = '|'

(* La riga separatore di una tabella: |---|:--:|---| *)
let is_table_sep line =
  String.length line > 0
  && String.for_all (fun c -> c = '-' || c = '|' || c = ' ' || c = ':') line
  && String.contains line '-'

(* parse_heading : string -> (int * string) option
   @ensures  Some (lvl, _)  =>  lvl >= 1  (almeno un '#' seguito da spazio)
   @ensures  None  se la riga non è un heading ben formato
   Nota: non c'è un massimo su lvl; l'emit mappa lvl >= 3 su subsubsection. *)
let parse_heading line =
  let len = String.length line in
  let n = ref 0 in
  while !n < len && line.[!n] = '#' do incr n done;
  if !n > 0 && !n < len && line.[!n] = ' '
  then begin
    assert (!n >= 1);
    Some (!n, String.trim (String.sub line (!n + 1) (len - !n - 1)))
  end
  else None

(* Immagine come unica cosa sulla riga: ![alt](path) *)
let parse_image line =
  let len = String.length line in
  if len > 4 && line.[0] = '!' && line.[1] = '[' then
    try
      let j = String.index line ']' in
      let alt = String.sub line 2 (j - 2) in
      if j + 1 < len && line.[j + 1] = '(' then
        let k = String.index_from line (j + 2) ')' in
        Some (Image (alt, String.sub line (j + 2) (k - j - 2)))
      else None
    with Not_found -> None
  else None

(* Voce bibliografia: "- [@chiave] Autore, anno. Titolo." *)
let parse_bib_line line =
  if is_list_item line then
    let content = String.sub line 2 (String.length line - 2) in
    let clen = String.length content in
    if clen > 3 && content.[0] = '[' && content.[1] = '@' then
      try
        let j = String.index content ']' in
        let key  = String.sub content 2 (j - 2) in
        let desc = String.trim (String.sub content (j + 1) (clen - j - 1)) in
        Some (key, desc)
      with Not_found -> None
    else None
  else None

(* Spezza "| a | b | c |" in ["a"; "b"; "c"]. *)
let parse_table_row line =
  String.split_on_char '|' line
  |> List.map String.trim
  |> List.filter (fun s -> s <> "")

let parse_list_item line =
  Lexer.parse (String.sub line 2 (String.length line - 2))

let parse_paragraph line = Paragraph (Lexer.parse line)


(* ---------- chiusura del contesto ----------
   Trasforma il contesto corrente nel block finito che rappresenta,
   e lo mette in cima all'accumulatore. Punto UNICO di chiusura. *)
let flush_ctx acc = function
  | Normal        -> acc
  | InList items  -> UnorderedList (List.rev items) :: acc
  | InBib entries -> Bibliography (List.rev entries) :: acc
  | InCode lines  -> CodeBlock (String.concat "\n" (List.rev lines)) :: acc
  | InTable (_, rows) ->
      (match List.rev rows with
       | header :: body -> Table (header, body) :: acc
       | []             -> acc)


(* ---------- il cuore: una riga alla volta ----------
   parse_lines : Diag.t -> string list -> block list
   Riceve il collector diagnostico e tutte le righe.
   Il numero di riga (1-based) viaggia come parametro `lineno`,
   incrementato a ogni passo, così il match resta su (ctx, line).

   Validazioni emesse:
     - tabella con righe di lunghezza diversa dall'header;
     - blocco di codice mai chiuso (fence aperta a fine file). *)
let parse_lines (diag : Diag.t) (lines : string list) : block list =

  (* close_table : block list -> string list list -> int -> block list
     Chiude una tabella, emettendo warning per righe con un numero di
     colonne diverso dall'header.
     @requires  open_line >= 1  (riga 1-based dell'header)
     @requires  rows è in ordine inverso di lettura (l'header è l'ULTIMO)
     @ensures   il risultato ha in testa un blocco Table (header, body)
                con header = prima riga letta, oppure acc invariato se
                rows è vuoto *)
  let close_table acc rows open_line =
    assert (open_line >= 1);
    match List.rev rows with
    | [] -> acc
    | header :: body ->
        let ncol = List.length header in
        (* body parte 2 righe dopo l'header (header + separatore) *)
        List.iteri (fun idx row ->
          let got = List.length row in
          if got <> ncol then
            Diag.warn diag ~line:(open_line + 2 + idx) ~phase:"parser"
              (Printf.sprintf
                 "tabella: header ha %d colonne ma questa riga ne ha %d"
                 ncol got)
        ) body;
        Table (header, body) :: acc
  in

  (* go : block list -> context -> int -> string list -> block list
     Consuma le righe una alla volta, mantenendo lo stato `ctx`.

     @invariant  acc contiene i block prodotti in ORDINE INVERSO;
                 l'ordine corretto è ripristinato da List.rev all'uscita.
     @invariant  lineno = (righe già consumate) + 1, cioè il numero
                 1-based della riga in testa a `rest`. ECCEZIONE: durante
                 la rielaborazione di una riga (rami che ripassano `l ::
                 rest` con `lineno` invariato anziché `next`), l'invariante
                 è sospeso di proposito per un passo — la riga viene
                 riclassificata in un nuovo contesto senza essere consumata.
     @invariant  ctx descrive il blocco multi-riga in costruzione; ogni
                 transizione di contesto passa per flush_ctx o close_table,
                 mai abbandona dati accumulati.
     @ensures    ogni riga dell'input contribuisce a esattamente un block
                 (nessuna riga persa, nessuna contata due volte). *)
  let rec go acc ctx lineno = function
    | [] ->
        (* fine file: controlla contesti rimasti aperti *)
        (match ctx with
         | InCode _ ->
             Diag.warn diag ~phase:"parser"
               "blocco di codice ``` non chiuso prima della fine del file"
         | _ -> ());
        List.rev (flush_ctx acc ctx)
    | line :: rest ->
      let next = lineno + 1 in
      assert (lineno >= 1);
      match ctx, line with

      (* --- blocco codice: ha la precedenza, dentro tutto è raw --- *)
      | InCode ls, l when is_fence l ->
          go (flush_ctx acc (InCode ls)) Normal next rest
      | InCode ls, l ->
          go acc (InCode (l :: ls)) next rest
      | Normal, l when is_fence l ->
          go acc (InCode []) next rest

      (* --- riga vuota: chiude liste/tabelle, ignorata altrove --- *)
      | InList _, "" ->
          go (flush_ctx acc ctx) Normal next rest
      | InTable (ol, rows), "" ->
          go (close_table acc rows ol) Normal next rest
      | _, "" ->
          go acc ctx next rest

      (* --- sezione bibliografia: heading speciale --- *)
      | _, l when parse_heading l = Some (2, "Bibliografia") ->
          go (flush_ctx acc ctx) (InBib []) next rest

      (* --- dentro la bibliografia --- *)
      | InBib es, l ->
          (match parse_bib_line l with
           | Some e -> go acc (InBib (e :: es)) next rest
           | None   ->
               (* riga non-bib: chiudi la bibliografia e rielabora la riga.
                  Rielaborando, NON incrementiamo lineno. *)
               go (flush_ctx acc ctx) Normal lineno (l :: rest))

      (* --- heading generico --- *)
      | _, l when parse_heading l <> None ->
          let (lvl, title) = Option.get (parse_heading l) in
          let acc' = flush_ctx acc ctx in
          go (Heading (lvl, Lexer.parse title) :: acc') Normal next rest

      (* --- tabelle --- *)
      | InTable (ol, rows), l when is_table_sep l ->
          go acc (InTable (ol, rows)) next rest         (* ignora separatore *)
      | InTable (ol, rows), l when is_table_row l ->
          go acc (InTable (ol, parse_table_row l :: rows)) next rest
      | InTable (ol, rows), l ->
          go (close_table acc rows ol) Normal lineno (l :: rest)
      | Normal, l when is_table_row l ->
          go acc (InTable (lineno, [parse_table_row l])) next rest

      (* --- immagine isolata --- *)
      | _, l when parse_image l <> None ->
          go (Option.get (parse_image l) :: flush_ctx acc ctx) Normal next rest

      (* --- liste --- *)
      | InList items, l when is_list_item l ->
          go acc (InList (parse_list_item l :: items)) next rest
      | _, l when is_list_item l ->
          go (flush_ctx acc ctx) (InList [parse_list_item l]) next rest

      (* --- paragrafo (caso di default) --- *)
      | _, l ->
          go (parse_paragraph l :: flush_ctx acc ctx) Normal next rest
  in
  go [] Normal 1 lines
