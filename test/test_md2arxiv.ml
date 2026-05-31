(* ============================================================
   test_md2arxiv.ml
   Test minimali ma significativi.
   Eseguiti con: dune test
   ============================================================ *)

open Md2arxiv
open Ast

let failures = ref 0

let check name cond =
  if cond then Printf.printf "  ok   %s\n" name
  else begin incr failures; Printf.printf "  FAIL %s\n" name end

(* ---------- LEXER ---------- *)
let () =
  print_endline "Lexer:";

  (* il bug classico: spazi dentro il grassetto *)
  check "bold con spazi"
    (Lexer.parse "**hello world**" = [Bold "hello world"]);

  check "misto"
    (Lexer.parse "a **b** c"
     = [Text "a "; Bold "b"; Text " c"]);

  check "citazione"
    (Lexer.parse "vedi [@hoare1969]."
     = [Text "vedi "; Cite "hoare1969"; Text "."]);

  check "link"
    (Lexer.parse "[Sito](https://x.com)"
     = [Link ("Sito", "https://x.com")]);

  check "codice inline"
    (Lexer.parse "usa `map` qui"
     = [Text "usa "; Code "map"; Text " qui"]);

  check "asterisco non chiuso resta testo"
    (Lexer.parse "2 * 3 = 6"
     = [Text "2 "; Text "* 3 = 6"]);

  check "link non terminato non perde testo"
    (let r = Lexer.parse "vedi [qui](http" in
     let s = String.concat "" (List.map (function
       | Text t -> t | _ -> "?") r) in
     s = "vedi [qui](http")

(* ---------- PARSER ---------- *)
let () =
  print_endline "Parser:";
  let d () = Diag.create () in  (* collector usa-e-getta per i test sintattici *)

  check "heading livello 1"
    (Parser.parse_lines (d ()) ["# Titolo"]
     = [Heading (1, [Text "Titolo"])]);

  check "heading livello 2"
    (Parser.parse_lines (d ()) ["## Sezione"]
     = [Heading (2, [Text "Sezione"])]);

  check "lista raggruppata"
    (Parser.parse_lines (d ()) ["- a"; "- b"; "- c"]
     = [UnorderedList [[Text "a"]; [Text "b"]; [Text "c"]]]);

  check "codice fenced grezzo"
    (Parser.parse_lines (d ()) ["```"; "let x = 1"; "```"]
     = [CodeBlock "let x = 1"]);

  check "tabella header + righe"
    (Parser.parse_lines (d ()) ["| A | B |"; "|---|---|"; "| 1 | 2 |"]
     = [Table (["A"; "B"], [["1"; "2"]])]);

  check "bibliografia"
    (Parser.parse_lines (d ()) ["## Bibliografia"; "- [@k1] Tizio, 2020. Titolo."]
     = [Bibliography [("k1", "Tizio, 2020. Titolo.")]])

(* ---------- META / ORCID ---------- *)
let () =
  print_endline "Meta:";

  check "orcid valido"
    (Meta.valid_orcid "0000-0001-2345-6789");

  check "orcid con X finale"
    (Meta.valid_orcid "0000-0001-2345-678X");

  check "orcid malformato rifiutato"
    (not (Meta.valid_orcid "123-456"));

  let fm = ["---"; "title: \"T\""; "arxiv_category: cs.LG"; "---"; "# Body"] in
  let (front, body) = Meta.split_frontmatter fm in
  let m = Meta.parse front in
  check "frontmatter title" (m.title = "T");
  check "frontmatter category" (m.category = "cs.LG");
  check "body separato" (body = ["# Body"])

(* ---------- EMIT ---------- *)
let () =
  print_endline "Emit:";

  check "bold -> textbf"
    (Emit.emit_inline (Bold "x") = "\\textbf{x}");

  check "escape ampersand"
    (Emit.escape "a & b" = "a \\& b");

  check "cite -> \\cite"
    (Emit.emit_inline (Cite "k") = "\\cite{k}")

(* ---------- DIAGNOSTICA ---------- *)
let () =
  print_endline "Diagnostica:";

  (* citazione orfana -> errore *)
  let d = Diag.create () in
  let blocks = Parser.parse_lines d
      ["Vedi [@manca]."; ""; "## Bibliografia"; "- [@altro] X, 2020."] in
  Validate.run d blocks;
  check "citazione orfana genera errore" (Diag.has_errors d);

  (* voce mai citata -> solo warning, niente errore *)
  let d = Diag.create () in
  let blocks = Parser.parse_lines d
      ["Testo senza citazioni."; ""; "## Bibliografia"; "- [@inutile] Y, 2021."] in
  Validate.run d blocks;
  let (w, e) = Diag.count d in
  check "voce non citata: warning, non errore" (w >= 1 && e = 0);

  (* tabella con righe incoerenti -> warning *)
  let d = Diag.create () in
  let _ = Parser.parse_lines d
      ["| A | B |"; "|---|---|"; "| solo_uno |"] in
  let (w, _) = Diag.count d in
  check "tabella incoerente genera warning" (w >= 1);

  (* fence non chiusa -> warning *)
  let d = Diag.create () in
  let _ = Parser.parse_lines d ["```"; "codice senza chiusura"] in
  let (w, _) = Diag.count d in
  check "fence aperta genera warning" (w >= 1);

  (* ORCID malformato nel frontmatter -> warning *)
  let d = Diag.create () in
  let _ = Meta.parse ~diag:d
      ["title: \"T\""; "authors:"; "  - name: \"A\"";
       "    affil: \"B\""; "    orcid: \"123\""] in
  let (w, _) = Diag.count d in
  check "ORCID malformato genera warning" (w >= 1);

  (* documento pulito -> nessun diagnostico *)
  let d = Diag.create () in
  let blocks = Parser.parse_lines d
      ["Vedi [@ok]."; ""; "## Bibliografia"; "- [@ok] Z, 2022."] in
  Validate.run d blocks;
  let (w, e) = Diag.count d in
  check "documento pulito: zero diagnostici" (w = 0 && e = 0)

(* ---------- esito ---------- *)
let () =
  print_endline "";
  if !failures = 0 then print_endline "TUTTI I TEST PASSATI"
  else begin
    Printf.printf "%d TEST FALLITI\n" !failures;
    exit 1
  end
