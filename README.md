# md2arxiv

[![OCaml](https://img.shields.io/badge/language-OCaml-orange.svg)](https://ocaml.org)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Status: alpha](https://img.shields.io/badge/status-alpha-orange.svg)]()
[![Theoretical Computer Science](https://img.shields.io/badge/Theoretical_Computer_Science-%E2%9A%9B%EF%B8%8F-purple)](https://en.wikipedia.org/wiki/Theoretical_computer_science)
[![Automata Theory](https://img.shields.io/badge/Automata_Theory-FA%2C_NFA%2C_PDA-orange)](https://en.wikipedia.org/wiki/Automata_theory)



> **⚠️ Alpha version.** Software in an early stage of development.
> 
> The accepted syntax and the output format may change without
> notice. Not yet tested on a wide variety of documents
> always check the generated `.tex` before a real submission.

A **Markdown to LaTeX** transpiler written in OCaml, designed to
generate packages ready for submission on **arXiv**. It is not a clone of Pandoc but
it is focused on a precise workflow, taking a `.md` with academic frontmatter 
(title, authors, ORCID, abstract) and producing a conforming `.tex`, with author block, 
affiliations and citations already in the right place. But it is also a **didactic project** that
shows the whole chain of a compiler in miniature, AST, lexer, parser, semantics, target,
on an understandable domain.

For the supported Markdown syntax with input/output examples for each
construct, see **[GUIDE.md](GUIDE.md)**.

> Una versione italiana di questo README è disponibile in **[README.it.md](README.it.md)**.

## Scope (important)

This tool handles **the subset of Markdown used in
academic writing**, NOT full CommonMark.

Supported: heading (`#`..`###`), paragraphs, **bold**, *italic*,
`inline code`, citations `[@key]`, links `[t](url)`, images
`![alt](path)`, unordered lists, code blocks ```` ``` ````,
tables with pipe `|`, `## Bibliografia` section, YAML frontmatter.

NOT supported: raw HTML, nested lists, nested, inline (`**_x_**`), ordered lists, footnotes, math (the `$` in text get escaped).


## Build and run

Requires OCaml (≥ 4.14) and dune.

```sh
dune build
dune test                      # runs the test suite
dune exec bin/main.exe -- test/sample.md -o paper.tex
# or
dune exec bin/main.exe < test/sample.md > paper.tex
# submission-ready package (paper.tex + figures/ copied):
dune exec bin/main.exe -- test/sample.md --package submission
# strict mode: warnings become fatal (useful in CI):
dune exec bin/main.exe -- test/sample.md --package submission --strict
```

## Architecture

One module, one responsibility. The dependency is one-way.

```
ast.ml      the abstract syntax (the contract)
diag.ml     collector of warnings/errors with line numbers
lexer.ml    string -> inline list   (char-by-char scan, a DFA by hand)
parser.ml   string list -> block list  (explicit context as a sum type)
meta.ml     YAML frontmatter -> meta record  (with ORCID validation)
validate.ml global semantic checks on the AST (orphan citations)
emit.ml     block -> LaTeX  (the denotational semantics)
arxiv.ml    meta + blocks -> complete .tex document (arXiv preamble)
package.ml  document -> submission-ready folder (.tex + figures/)
bin/main.ml CLI, diagnostics orchestration, exit code
```

About the diagnostics, a single `Diag.t` goes through all the phases that
feed it without changing their own signatures. No phase halts at the
first problem but everything is collected and reported together at the end,
with line numbers. See [GUIDE.md](GUIDE.md) §13.

The pipeline:

```
raw lines
  │  Meta.split_frontmatter
  ├── frontmatter ── Meta.parse ───────────► meta ───┐
  └── body ───────── Parser.parse_lines ───► blocks ─┤
                          │                          │
                          ▼                          ▼
                     Validate.run            Arxiv.emit_document
                  (orphan citations)            (uses Emit)
                          │                          │
                          └──────► Diag.t ◄──────────┘
                                     │
                          Diag.report -> stderr + exit code
```

Every phase writes into the same `Diag.t`; the `.tex` output comes out anyway,
but the exit code is 1 if there are errors (or warnings in `--strict`).

## Contracts and invariants

The code is annotated with contracts in formal style as is customary in
Eiffel/JML/Frama-C, to document the assumptions of each function
and give whoever rereads it something against which to verify the
body:

- `@requires` : precondition that the caller must guarantee;
- `@ensures` : postcondition guaranteed on exit;
- `@invariant` : property kept during a recursion or on the type;
- `@raises` : exceptions raised and under which conditions;
- `@note` : non-obvious constraint not to be violated (e.g. evaluation order).

Where the invariant is local and low-cost it is also an `assert` that runs, so in this way, during `dune test` (and in every build without `-noassert`) it self-checks. 

Examples: the lexer cursor stays within bounds (`read_until`), a normalized table row has exactly `cols` cells (`emit.ml`), a heading has level ≥ 1 (`parse_heading`).

Where instead the invariant is structural or costly it stays only as a comment
(e.g. the reverse order of the accumulators, the semantics of `lineno` in the
parser). The checks on user input are NOT asserts but they are real diagnostics (see above) so an `assert` disappears with `-noassert`, an input validation must always hold.

## Why no .bib + BibTeX

The arXiv TeX environment does not run BibTeX, and we generate directly `\begin{thebibliography}` inline from the `## Bibliografia` section. This removes the manual step (running bibtex,
copying the `.bbl`) that other workflows require so the `.tex` that we produce is already self-contained and ready.

**Formal semantics**

The companion document `semantics.pdf` provides a formal treatment of the core of `md2arxiv` in two styles, denotational and axiomatic. The denotational semantics defines meaning functions $\mathcal{I}\llbracket\cdot\rrbracket : \mathbf{Inline} \to \mathbf{String}$ and $\mathcal{B}\llbracket\cdot\rrbracket : \mathbf{Block} \to \mathbf{String}$ by structural induction on the AST, following the compositional approach of Strachey and Scott. The emit pipeline is then characterized as the least fixed point of a continuous operator on the CPO $(\mathbf{String}_\perp, \sqsubseteq)$ ordered by prefix, via the Knaster-Tarski theorem. The axiomatic semantics specifies the stateful functions of the lexer (`read_until`, `try_delim`) as Hoare triples, formalizing the `@requires`/`@ensures` contracts already present in the source.


## Roadmap

- v2: backend for the NeurIPS-like style `arxiv.sty`
  (<https://github.com/kourgeorge/arxiv-style>, MIT) via flag
  `--style=neurips`. Same AST, different emit, the demonstration that
  parsing and emit are decoupled.

## References

### OCaml
- Minsky, Madhavapeddy : *Real World OCaml* (2nd ed., open access)
  <https://dev.realworldocaml.org>

### Semantics of languages
- Giorgio Levi, Unipi : *Linguaggi di Programmazione*
  <http://groups.di.unipi.it/~levi/corsoLP/pagina.html>

### Automata and computability
- MIT OCW 18.404J : *Theory of Computation*, M. Sipser
  <https://ocw.mit.edu/courses/18-404j-theory-of-computation-fall-2020/>
- MIT OCW 6.045J : *Automata, Computability and Complexity*, S. Aaronson
  <https://ocw.mit.edu/courses/6-045j-automata-computability-and-complexity-spring-2011/>

### Compilers
- Stanford / edX : *Compilers*, A. Aiken
- Aho, Lam, Sethi, Ullman : *Compilers: Principles, Techniques and Tools*
  ("Dragon Book")

## License

MIT — see [LICENSE](LICENSE).
