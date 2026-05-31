# md2arxiv usage guide

**Fabio F.G. Buono**

> Una versione italiana di questa guida è disponibile in **[GUIDE.it.md](GUIDE.it.md)**.

1. Frontmatter (metadata)
2. Headings and sections
3. Text: bold, italic, code
4. Citations
5. Links
6. Images
7. Lists
8. Code blocks
9.  Tables
10. Bibliography
11. Special characters (escaping)
12. Diagnostics and checks
13. Generating the package

---

## 1. Frontmatter

```markdown
---
title: "AsdfAsdfAsdf"
authors:
  - name:  "Pippo"
    affil: "Università di Genova"
    orcid: "0000-0000-98989-0000"
    email: "pippopluto@unito.it"
  - name:  "James Kirk"
    affil: "University of Cambridge"
abstract: |
  ....bla bla bla...
keywords: [..., ..., ...]
arxiv_category: cs.LG
date: 2026-05-29
---
```

Notes on the fields:
- `title` : string, quotes recommended
- `authors` : list, each entry starts with `- name:`. The `orcid`
  and `email` fields are optional.
- `orcid` : format `XXXX-XXXX-XXXX-XXXX` (the last digit can be `X`).
  A malformed ORCID produces a warning (see §13) and is ignored,
  without blocking generation.
- `abstract` : use `|` for multiline text (the lines must be indented
  by at least 2 spaces); or on a single line between quotes.
- `keywords` : list between square brackets, separated by commas.
- `date` : if omitted, LaTeX will use `\today`.

Produces in the preamble: `\title{...}`, a `\author{... \and ...}` block
with clickable ORCID (`\orcidlink`) and affiliation in `\thanks{}`,
the `abstract` environment, and the keywords/category as comments.

---

## 2. Headings and sections

```markdown
# Titolo principale
## Sottosezione
### Sotto-sottosezione
```

Mapping:

| Markdown | LaTeX           |
|----------|-----------------|
| `#`      | `\section`      |
| `##`     | `\subsection`   |
| `###`    | `\subsubsection`|

A space is needed after the `#`. Headings can contain inline
formatting (e.g. `# Il teorema di **Bayes**`).

Warning: `## Bibliografia` is special (see section 11).

---

## 4. Text: bold, italic, code

```markdown
Questo è **grassetto**, questo *corsivo*, e questo `codice inline`.
```

Produces:

```latex
Questo è \textbf{grassetto}, questo \emph{corsivo}, e questo \texttt{codice inline}.
```

The lexer correctly handles internal spaces: `**due parole**`
becomes `\textbf{due parole}`, it does not split. An isolated asterisk
(e.g. in `2 * 3`) stays as literal text.

---

## 5. Citations

```markdown
Come dimostrato in precedenza [@hoare1969], il problema è decidibile.
```

Produces:

```latex
Come dimostrato in precedenza \cite{hoare1969}, il problema è decidibile.
```

The key inside `[@...]` must correspond to an entry in the
`## Bibliografia` section (see section 11).

---

## 6. Links

```markdown
Vedi il [sito del progetto](https://example.com) per i dettagli.
```

Produces:

```latex
Vedi il \href{https://example.com}{sito del progetto} per i dettagli.
```

Requires `\usepackage{hyperref}` (already in the preamble). If the syntax
is not complete (the `(url)` part is missing), the text stays literal.

---

## 7. Images

The image goes alone on its own line:

```markdown
![Diagramma dell'architettura](figure/arch.png)
```

Produces:

```latex
\begin{figure}[h]
  \centering
  \includegraphics[width=0.8\linewidth]{figure/arch.png}
  \caption{Diagramma dell'architettura}
\end{figure}
```

In `--package` mode, the image file is copied to
`figures/` and the path in the `.tex` is rewritten accordingly.

---

## 8. Lists

Unordered lists, one element per line with `- `:

```markdown
- primo elemento
- secondo elemento con **grassetto**
- terzo elemento
```

Produces:

```latex
\begin{itemize}
  \item primo elemento
  \item secondo elemento con \textbf{grassetto}
  \item terzo elemento
\end{itemize}
```

The list is closed by an empty line or a block of a different type.
The elements can contain inline formatting.

---

## 9. Code blocks

Delimited by three backticks on their own lines:

````markdown
```
let rec fact n =
  if n = 0 then 1 else n * fact (n - 1)
```
````

Produces:

```latex
\begin{verbatim}
let rec fact n =
  if n = 0 then 1 else n * fact (n - 1)
\end{verbatim}
```

Inside the block nothing is interpreted: no escaping, no
inline formatting. It is raw text.

---

## 10. Tables

Pipe syntax. The first row is the header, the second is the separator
(ignored), the following ones are the data:

```markdown
| Metodo | Accuratezza | Tempo |
|--------|-------------|-------|
| SGD    | 0.91        | 12s   |
| Adam   | 0.93        | 15s   |
```

Produces (using `booktabs`):

```latex
\begin{center}
\begin{tabular}{lll}
\toprule
Metodo & Accuratezza & Tempo \\
\midrule
SGD & 0.91 & 12s \\
Adam & 0.93 & 15s \\
\bottomrule
\end{tabular}
\end{center}
```

All columns are left-aligned (`l`). The separator row
can use `:` to indicate alignment in Markdown, but for now it is
ignored (see limits).

---

## 11. Bibliography

The `## Bibliografia` section activates a special mode. Each entry
is a list element that starts with the key `[@chiave]`:

```markdown
## Bibliografia

- [@hoare1969] Hoare, 1969. Communicating Sequential Processes.
- [@dijkstra1975] Dijkstra, 1975. Guarded Commands, Nondeterminacy.
```

Produces:

```latex
\begin{thebibliography}{99}
  \bibitem{hoare1969} Hoare, 1969. Communicating Sequential Processes.
  \bibitem{dijkstra1975} Dijkstra, 1975. Guarded Commands, Nondeterminacy.
\end{thebibliography}
```

The keys (`hoare1969`) are the ones that the `[@hoare1969]` point to
in the text. The bibliography is generated inline, without `.bib` nor BibTeX:
so the `.tex` is already ready for arXiv.

---

## 12. Special characters (escaping)

The characters that in LaTeX have special meaning are
automatically protected in normal text:

| Character | Becomes              |
|-----------|----------------------|
| `&`       | `\&`                 |
| `%`       | `\%`                 |
| `$`       | `\$`                 |
| `#`       | `\#`                 |
| `_`       | `\_`                 |
| `{` `}`   | `\{` `\}`            |
| `~`       | `\textasciitilde{}`  |
| `^`       | `\textasciicircum{}` |
| `\`       | `\textbackslash{}`   |

So writing `il 50% dei casi` produces `il 50\% dei casi`.

---

## 13. Diagnostics and checks

The tool checks the document and reports the problems on stderr, with line number, without stopping at the first one (compiler style). The diagnostics are of two kinds:

- **warning** : the output is generated anyway;
- **error** : the output is unreliable; the exit code is 1.

Format:

```
paper.md:12: error [validate]: citazione [@manca] senza voce corrispondente in ## Bibliografia
paper.md:30: warning [parser]: tabella: header ha 3 colonne ma questa riga ne ha 2
```

Checks performed:

| Check                                       | Kind    | Phase    |
|---------------------------------------------|---------|----------|
| Citation `[@k]` without entry in bibliography | error | validate |
| Bibliography entry never cited              | warning | validate |
| Table with rows of different length         | warning | parser   |
| Block ``` never closed                      | warning | parser   |
| Image referenced but file missing           | error   | package  |
| Malformed ORCID                             | warning | meta     |
| Missing `title` / no author                 | warning | meta     |
| Author without affiliation                  | warning | meta     |

Strict mode: with `--strict` even warnings become fatal
(exit code 1). Useful in a CI pipeline so as not to let a
document with problems through:

```sh
dune exec bin/main.exe -- paper.md --package out --strict
```

---

## 14. Generating the package

Just the `.tex`:

```sh
dune exec bin/main.exe -- paper.md -o paper.tex
```

Submission-ready folder (`.tex` + copied figures):

```sh
dune exec bin/main.exe -- paper.md --package submission
tar czf submission.tar.gz submission/    # ready for upload
```

The `submission/` folder will contain `paper.tex` and, if there are
images, `figures/` with the copies.

---
