(* ============================================================
   package.ml
   Costruzione del pacchetto submission-ready.

   arXiv vuole una cartella autocontenuta:
     submission/
       paper.tex      (con \begin{thebibliography} INLINE e nessun .bbl)
       figures/       (le immagini referenziate, copiate qui)

   Generiamo direttamente thebibliography inline (lo fa già Emit). 
   Questo elimina il passo manuale .bbl che altri workflow richiedono.
   ============================================================ *)

open Ast

(* Raccoglie i path di tutte le immagini nel documento. *)
let collect_images (blocks : block list) : string list =
  List.filter_map (function Image (_, path) -> Some path | _ -> None) blocks

(* Riscrive i path immagine in "figures/<basename>" dentro l'AST,
   così il .tex punta alle copie nella cartella di submission. *)
(* rewrite_image_paths : block list -> block list
   @ensures  ogni Image (_, p) diventa Image (_, "figures/" ^ basename p)
   @ensures  i block non-Image sono invariati
   @ensures  |risultato| = |blocks|  (mappa 1-a-1, nessun blocco perso) *)
let rewrite_image_paths (blocks : block list) : block list =
  List.map (function
    | Image (alt, path) -> Image (alt, "figures/" ^ Filename.basename path)
    | b -> b) blocks

(* copy_file : string -> string -> bool
   Copia binaria di src in dst.
   @ensures  i canali aperti vengono SEMPRE chiusi, anche in caso di
             eccezione (nessun file descriptor trapelato)
   @ensures  ritorna true sse la copia è andata a buon fine *)
let copy_file src dst =
  match open_in_bin src with
  | exception Sys_error msg ->
      Printf.eprintf "Attenzione: impossibile aprire %s (%s)\n" src msg;
      false
  | ic ->
    (match open_out_bin dst with
     | exception Sys_error msg ->
         close_in_noerr ic;
         Printf.eprintf "Attenzione: impossibile creare %s (%s)\n" dst msg;
         false
     | oc ->
       let ok =
         try
           let len = 4096 in
           let buf = Bytes.create len in
           let rec loop () =
             let n = input ic buf 0 len in
             if n > 0 then (output oc buf 0 n; loop ())
           in
           loop (); true
         with Sys_error msg ->
           Printf.eprintf "Attenzione: errore copiando %s (%s)\n" src msg;
           false
       in
       (* chiusura garantita di entrambi i canali *)
       close_in_noerr ic;
       close_out_noerr oc;
       ok)

(* mkdir senza errore se esiste già. *)
let ensure_dir d =
  if not (Sys.file_exists d) then Unix.mkdir d 0o755

(* package : document -> src_dir -> out_dir -> unit
   src_dir: dove stanno le immagini originali (relative al .md)
   out_dir: cartella di submission da creare *)
let build ?diag ~(doc : document) ~(src_dir : string) ~(out_dir : string) : unit =
  ensure_dir out_dir;
  let fig_dir = Filename.concat out_dir "figures" in

  let images = collect_images doc.blocks in
  if images <> [] then ensure_dir fig_dir;

  (* copia ogni immagine in figures/, segnalando le mancanti *)
  List.iter (fun path ->
    let src = if Filename.is_relative path
              then Filename.concat src_dir path else path in
    let dst = Filename.concat fig_dir (Filename.basename path) in
    if not (Sys.file_exists src) then
      (match diag with
       | Some d -> Diag.error d ~phase:"package"
                     (Printf.sprintf
                        "immagine non trovata: %s (il .tex la referenzia ma il file manca)"
                        src)
       | None -> Printf.eprintf "Errore: immagine non trovata: %s\n" src)
    else if not (copy_file src dst) then
      (match diag with
       | Some d -> Diag.error d ~phase:"package"
                     (Printf.sprintf "copia fallita: %s" src)
       | None -> ())
  ) images;

  (* riscrivi i path e genera il .tex *)
  let doc' = { doc with blocks = rewrite_image_paths doc.blocks } in
  let latex = Arxiv.emit_document doc' in
  let tex_path = Filename.concat out_dir "paper.tex" in
  let oc = (try open_out tex_path
            with Sys_error msg ->
              (match diag with
               | Some d -> Diag.error d ~phase:"package"
                             (Printf.sprintf "impossibile scrivere %s: %s" tex_path msg)
               | None -> Printf.eprintf "Errore: impossibile scrivere %s: %s\n" tex_path msg);
              exit 1) in
  output_string oc latex;
  close_out oc;

  Printf.eprintf "Pacchetto creato in %s/\n  paper.tex\n%s"
    out_dir
    (if images = [] then ""
     else Printf.sprintf "  figures/ (%d immagini)\n" (List.length images))
