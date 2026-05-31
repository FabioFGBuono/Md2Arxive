(* ============================================================
   emit.ml
   AST -> LaTeX (corpo del documento).

   Ogni costrutto ha un significato, espresso come stringa LaTeX.
   
   Funzione pura, compositiva: emit(blocco) non dipende da nient'altro.

   Riferimento: Levi, semantica denotazionale: il "significato"
   di un albero è definito per induzione sulla sua struttura.
   ============================================================ *)

open Ast

(* Escape dei caratteri speciali LaTeX nel testo grezzo.
   IMPORTANTE per robustezza: un '%' o '&' non escappato rompe il .tex. *)
let escape (s : string) : string =
  let buf = Buffer.create (String.length s + 8) in
  String.iter (fun c ->
    match c with
    | '&' | '%' | '$' | '#' | '_' | '{' | '}' ->
        Buffer.add_char buf '\\'; Buffer.add_char buf c
    | '~' -> Buffer.add_string buf "\\textasciitilde{}"
    | '^' -> Buffer.add_string buf "\\textasciicircum{}"
    | '\\' -> Buffer.add_string buf "\\textbackslash{}"
    | c -> Buffer.add_char buf c
  ) s;
  Buffer.contents buf

(* --- inline -> LaTeX ---
   Nota: dentro \texttt e url NON si escapa allo stesso modo,
   ma per semplicità didattica escapiamo il testo "normale". *)
let emit_inline = function
  | Text s        -> escape s
  | Bold s        -> "\\textbf{" ^ escape s ^ "}"
  | Italic s      -> "\\emph{" ^ escape s ^ "}"
  | Code s        -> "\\texttt{" ^ escape s ^ "}"
  | Cite key      -> "\\cite{" ^ key ^ "}"
  | Link (t, url) -> "\\href{" ^ url ^ "}{" ^ escape t ^ "}"

let emit_inlines inls =
  String.concat "" (List.map emit_inline inls)

(* --- block -> LaTeX --- *)
let emit_block = function
  | Heading (lvl, inls) ->
      let cmd = match lvl with
        | 1 -> "\\section"
        | 2 -> "\\subsection"
        | _ -> "\\subsubsection"
      in
      cmd ^ "{" ^ emit_inlines inls ^ "}\n\n"

  | Paragraph inls ->
      emit_inlines inls ^ "\n\n"

  | UnorderedList items ->
      "\\begin{itemize}\n"
      ^ String.concat ""
          (List.map (fun i -> "  \\item " ^ emit_inlines i ^ "\n") items)
      ^ "\\end{itemize}\n\n"

  | CodeBlock code ->
      (* verbatim: niente escape, è codice grezzo *)
      "\\begin{verbatim}\n" ^ code ^ "\n\\end{verbatim}\n\n"

  | Image (alt, path) ->
      "\\begin{figure}[h]\n"
      ^ "  \\centering\n"
      ^ "  \\includegraphics[width=0.8\\linewidth]{" ^ path ^ "}\n"
      ^ "  \\caption{" ^ escape alt ^ "}\n"
      ^ "\\end{figure}\n\n"

  | Table (header, rows) ->
      let cols = List.length header in
      let spec = String.concat "" (List.init cols (fun _ -> "l")) in
      (* Normalizza ogni riga a `cols` celle: tronca le troppo lunghe,
         padda con celle vuote le troppo corte. Così il .tex compila
         sempre, anche se il Markdown aveva righe incoerenti (il parser
         ha già emesso un warning in quel caso). *)
      (* normalize : string list -> string list
         Porta una riga a esattamente `cols` celle.
         @ensures  |risultato| = cols
                   (e' la proprieta' che garantisce un tabular valido:
                    ogni riga ha lo stesso numero di & dell'header) *)
      let normalize cells =
        let n = List.length cells in
        let result =
          if n = cols then cells
          else if n > cols then List.filteri (fun i _ -> i < cols) cells
          else cells @ List.init (cols - n) (fun _ -> "")
        in
        assert (List.length result = cols);
        result
      in
      let row cells =
        String.concat " & " (List.map escape (normalize cells)) ^ " \\\\\n"
      in
      "\\begin{center}\n"
      ^ "\\begin{tabular}{" ^ spec ^ "}\n"
      ^ "\\toprule\n"
      ^ row header
      ^ "\\midrule\n"
      ^ String.concat "" (List.map row rows)
      ^ "\\bottomrule\n"
      ^ "\\end{tabular}\n"
      ^ "\\end{center}\n\n"

  | Bibliography entries ->
      "\\begin{thebibliography}{99}\n"
      ^ String.concat ""
          (List.map (fun (k, desc) ->
             "  \\bibitem{" ^ k ^ "} " ^ escape desc ^ "\n") entries)
      ^ "\\end{thebibliography}\n\n"

(* L'intero corpo. *)
let emit_body (blocks : block list) : string =
  String.concat "" (List.map emit_block blocks)
