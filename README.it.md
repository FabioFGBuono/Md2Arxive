# md2arxiv

**Autore: Fabio F.G. Buono**

> **⚠️ Versione alfa.** Software in fase iniziale di sviluppo.
> 
> La sintassi accettata e il formato dell'output possono cambiare senza
> preavviso. Non ancora collaudato su un'ampia varietà di documenti
> verifica sempre il `.tex` generato prima di una submission reale.

Un transpiler **Markdown to LaTeX** scritto in OCaml, pensato per
generare pacchetti pronti per la submission su **arXiv**. Non è un clone di Pandoc ma
è focalizzato su un workflow preciso, prendere un `.md` con frontmatter accademico 
(titolo, autori, ORCID, abstract) e produce un `.tex` conforme, con blocco autori, 
affiliazioni e citazioni già al posto giusto. Ma è anche un **progetto didattico** che
mostra l'intera catena di un compilatore in miniatura, AST, lexer, parser, semantica, target,
su un dominio comprensibile.

Per la sintassi Markdown supportata con esempi input/output per ogni
costrutto, vedi **[GUIDE.it.md](GUIDE.it.md)**.

## Scope (importante)

Questo strumento gestisce **il sottoinsieme di Markdown usato nella
scrittura accademica**, NON CommonMark completo.

Supportato: heading (`#`..`###`), paragrafi, **grassetto**, *corsivo*,
`codice inline`, citazioni `[@chiave]`, link `[t](url)`, immagini
`![alt](path)`, liste non ordinate, blocchi di codice ```` ``` ````,
tabelle con pipe `|`, sezione `## Bibliografia`, frontmatter YAML.

NON supportato: HTML grezzo, liste annidate, inline
annidati (`**_x_**`), liste ordinate, note a piè di pagina, math
(i `$` nel testo vengono escapati)

## Build ed esecuzione

Richiede OCaml (≥ 4.14) e dune.

```sh
dune build
dune test                      # esegue la test suite
dune exec bin/main.exe -- test/sample.md -o paper.tex
# oppure
dune exec bin/main.exe < test/sample.md > paper.tex
# pacchetto submission-ready (paper.tex + figures/ copiate):
dune exec bin/main.exe -- test/sample.md --package submission
# modalità rigorosa: i warning diventano fatali (utile in CI):
dune exec bin/main.exe -- test/sample.md --package submission --strict
```

## Architettura

Un modulo, una responsabilità. La dipendenza è a senso unico.

```
ast.ml      la sintassi astratta (il contratto)
diag.ml     collector di warning/errori con numeri di riga
lexer.ml    string -> inline list   (scansione char-by-char, un DFA a mano)
parser.ml   string list -> block list  (contesto esplicito come tipo somma)
meta.ml     frontmatter YAML -> record meta  (con validazione ORCID)
validate.ml controlli semantici globali sull'AST (citazioni orfane)
emit.ml     block -> LaTeX  (la semantica denotazionale)
arxiv.ml    meta + blocks -> documento .tex completo (preamble arXiv)
package.ml  document -> cartella submission-ready (.tex + figures/)
bin/main.ml CLI, orchestrazione della diagnostica, exit code
```

Riguardo la diagnostica, un unico `Diag.t` attraversa tutte le fasi che lo
alimentano senza cambiare le proprie firme. Nessuna fase si pianta al
primo problema ma si raccoglie tutto e si riporta insieme alla fine,
con numeri di riga. Vedi [GUIDE.md](GUIDE.it.md) §13.

La pipeline:

```
righe grezze
  │  Meta.split_frontmatter
  ├── frontmatter ── Meta.parse ───────────► meta ───┐
  └── corpo ──────── Parser.parse_lines ───► blocks ─┤
                          │                          │
                          ▼                          ▼
                     Validate.run            Arxiv.emit_document
                  (citazioni orfane)            (usa Emit)
                          │                          │
                          └──────► Diag.t ◄──────────┘
                                     │
                          Diag.report -> stderr + exit code
```

Ogni fase scrive nello stesso `Diag.t`; l'output `.tex` esce comunque,
ma l'exit code è 1 se ci sono errori (o warning in `--strict`).

## Contratti e invarianti

Il codice è annotato con contratti in stile formale come è prassi in
Eiffel / JML / Frama-C, per documentare le assunzioni di ogni funzione
e dare a chi rilegge qualcosa contro cui verificare il
corpo:

- `@requires` : precondizione che il chiamante deve garantire;
- `@ensures` : postcondizione garantita all'uscita;
- `@invariant` : proprietà mantenuta durante una ricorsione o sul tipo;
- `@raises` : eccezioni sollevate e in quali condizioni;
- `@note` : vincolo non ovvio da non violare (es. ordine di valutazione).

Dove l'invariante è locale e a basso costo è anche un `assert`
eseguibile: durante `dune test` (e in ogni build senza `-noassert`) si
autoverifica. 

Esempi: il cursore del lexer resta nei limiti (`read_until`), una riga di tabella normalizzata ha esattamente `cols` celle (`emit.ml`), un heading ha livello ≥ 1 (`parse_heading`).

Dove invece l'invariante è strutturale o costoso resta solo commento (es. l'ordine inverso degli accumulatori, la semantica di `lineno` nel parser). I controlli sull'input dell'utente NON sono assert ma diagnostici veri e un `assert` sparisce con `-noassert`, una validazione di input deve valere sempre.

## Perché niente .bib + BibTeX

L'ambiente TeX di arXiv non esegue BibTeX, quindi generiamo
direttamente `\begin{thebibliography}` inline dalla sezione
`## Bibliografia`. Questo elimina il passo manuale (girare bibtex,
copiare il `.bbl`) che altri workflow richiedono e il `.tex` che
produciamo è già autocontenuto e pronto.

**Semantica formale**

Il documento `semantica.pdf` contiene un trattamento formale del nucleo di `md2arxiv`. La semantica denotazionale definisce le funzioni di significato $\mathcal{I}\llbracket\cdot\rrbracket : \mathbf{Inline} \to \mathbf{String}$ e $\mathcal{B}\llbracket\cdot\rrbracket : \mathbf{Block} \to \mathbf{String}$ per induzione strutturale sull'AST, seguendo l'approccio composizionale di Strachey e Scott. La pipeline di emissione è poi caratterizzata come minimo punto fisso di un operatore continuo sul CPO $(\mathbf{String}_\perp, \sqsubseteq)$ ordinato per prefisso, via il Teorema di Knaster-Tarski.


## Roadmap

- v2: backend per lo stile NeurIPS-like `arxiv.sty`
  (<https://github.com/kourgeorge/arxiv-style>, MIT) tramite flag
  `--style=neurips`. Stesso AST, emit diverso, la dimostrazione che
  parsing ed emit sono disaccoppiati.

## Riferimenti

### OCaml
- Minsky, Madhavapeddy - *Real World OCaml* (2ª ed., open access)
  <https://dev.realworldocaml.org>

### Semantica dei linguaggi
- Giorgio Levi, Unipi - *Linguaggi di Programmazione*
  <http://groups.di.unipi.it/~levi/corsoLP/pagina.html>

### Automi e calcolabilità
- MIT OCW 18.404J - *Theory of Computation*, M. Sipser
  <https://ocw.mit.edu/courses/18-404j-theory-of-computation-fall-2020/>
- MIT OCW 6.045J - *Automata, Computability and Complexity*, S. Aaronson
  <https://ocw.mit.edu/courses/6-045j-automata-computability-and-complexity-spring-2011/>

### Compilatori
- Stanford / edX - *Compilers*, A. Aiken
- Aho, Lam, Sethi, Ullman - *Compilers: Principles, Techniques and Tools*
  ("Dragon Book")

## Licenza

MIT — vedi [LICENSE](LICENSE).
