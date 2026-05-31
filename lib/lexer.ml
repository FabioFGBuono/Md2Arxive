(* ============================================================
   lexer.ml
   Analisi degli inline, carattere per carattere.

   Riferimento: MIT 18.404J (automi finiti), questo lexer
   è essenzialmente un DFA scritto a mano. 
   Real World OCaml cap. 8 (Imperative Programming) per i ref.
   ============================================================ *)

open Ast

(* parse : string -> inline list
   Trasforma una riga di testo nella sua lista di inline. *)
let parse (s : string) : inline list =
  let len = String.length s in
  let buf = Buffer.create 64 in   (* testo grezzo accumulato *)
  let i   = ref 0 in              (* cursore di scansione    *)
  let acc = ref [] in             (* inline raccolti (rovesci) *)

  (* Svuota il buffer come nodo Text, se non vuoto. *)
  let flush () =
    if Buffer.length buf > 0 then begin
      acc := Text (Buffer.contents buf) :: !acc;
      Buffer.clear buf
    end
  in

  (* read_until : string -> string
     Legge da !i fino a trovare la stringa delim.
     @requires  delim <> ""  &&  0 <= !i <= len
     @ensures   (caso successo) il risultato è s[i_pre .. j),
                e !i = j + |delim|, con i_pre <= j <= len - |delim|
     @ensures   (caso fallimento) solleva Not_found e NON modifica !i
     @raises    Not_found  se delim non compare a partire da !i *)
  let read_until delim =
    assert (String.length delim > 0);
    assert (!i >= 0 && !i <= len);
    let i_pre = !i in
    let dlen = String.length delim in
    let j = ref !i in
    while !j + dlen <= len && String.sub s !j dlen <> delim do
      incr j
    done;
    if !j + dlen > len then raise Not_found;  (* !i resta = i_pre *)
    let content = String.sub s !i (!j - !i) in
    i := !j + dlen;
    assert (!i > i_pre && !i <= len);          (* il cursore è avanzato e in range *)
    ignore i_pre;
    content
  in

  (* try_delim : int -> string -> (string -> inline) -> string -> unit
     Prova a leggere un costrutto delimitato; in caso di delimitatore
     non chiuso, reintegra `fallback_str` come testo letterale.
     @requires  |fallback_str| = open_len
                (il fallback deve compensare l'avanzamento di !i,
                 altrimenti si perde o si duplica testo)
     @ensures   !i è avanzato; nessun carattere di input è perso *)
  let try_delim open_len delim make fallback_str =
    assert (String.length fallback_str = open_len);
    flush ();
    i := !i + open_len;
    (try acc := make (read_until delim) :: !acc
     with Not_found -> Buffer.add_string buf fallback_str)
  in

  while !i < len do
    let c = s.[!i] in
    (* Bold: **...** (controlla DUE asterischi prima del singolo) *)
    if c = '*' && !i + 1 < len && s.[!i + 1] = '*' then
      try_delim 2 "**" (fun x -> Bold x) "**"

    (* Italic: *...* *)
    else if c = '*' then
      try_delim 1 "*" (fun x -> Italic x) "*"

    (* Code: `...` *)
    else if c = '`' then
      try_delim 1 "`" (fun x -> Code x) "`"

    (* Citazione: [@chiave] *)
    else if c = '[' && !i + 1 < len && s.[!i + 1] = '@' then
      try_delim 2 "]" (fun x -> Cite x) "[@"

    (* Link: [testo](url) — due fasi *)
    else if c = '[' then begin
      flush ();
      let start = !i in              (* memorizza per reintegro completo *)
      i := !i + 1;
      (try
         let text = read_until "]" in
         if !i < len && s.[!i] = '(' then begin
           i := !i + 1;
           (try
              let url = read_until ")" in
              acc := Link (text, url) :: !acc
            with Not_found ->
              (* '(' aperta ma mai chiusa: reintegra TUTTO dal '[' *)
              Buffer.add_string buf (String.sub s start (!i - start)))
         end else begin
           (* non era un link: reintegra letteralmente *)
           Buffer.add_char buf '[';
           Buffer.add_string buf text;
           Buffer.add_char buf ']'
         end
       with Not_found -> Buffer.add_char buf '[')
    end

    (* Carattere ordinario *)
    else begin
      Buffer.add_char buf c;
      i := !i + 1
    end
  done;

  flush ();
  List.rev !acc
