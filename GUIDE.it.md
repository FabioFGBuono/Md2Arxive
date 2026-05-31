# Guida all'uso di md2arxiv

**Fabio F.G. Buono**

1. Frontmatter (metadati)
2. Titoli e sezioni
3. Testo: grassetto, corsivo, codice
4. Citazioni
5. Link
6. Immagini
7. Liste
8. Blocchi di codice
9.  Tabelle
10. Bibliografia
11. Caratteri speciali (escaping)
12. Diagnostica e controlli
13. Generare il pacchetto

---

## 1. Frontmatter (metadati)

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

Note sui campi:
- `title` - stringa, virgolette consigliate.
- `authors` - lista, ogni voce inizia con `- name:`. I campi `orcid`
  ed `email` sono opzionali.
- `orcid` - formato `XXXX-XXXX-XXXX-XXXX` (l'ultima cifra può essere `X`).
  Un ORCID malformato produce un warning (vedi §13) e viene ignorato,
  senza bloccare la generazione.
- `abstract` - usa `|` per testo multilinea (le righe vanno indentate
  di almeno 2 spazi); oppure su una riga sola tra virgolette.
- `keywords` - lista tra parentesi quadre, separata da virgole.
- `date` - se omesso, LaTeX userà `\today`.

Produce nel preamble: `\title{...}`, un blocco `\author{... \and ...}`
con ORCID cliccabile (`\orcidlink`) e affiliazione in `\thanks{}`,
l'ambiente `abstract`, e le keyword/categoria come commenti.

---

## 2. Titoli e sezioni

```markdown
# Titolo principale
## Sottosezione
### Sotto-sottosezione
```

Mappatura:

| Markdown | LaTeX           |
|----------|-----------------|
| `#`      | `\section`      |
| `##`     | `\subsection`   |
| `###`    | `\subsubsection`|

Serve uno spazio dopo i `#`. I titoli possono contenere formattazione
inline (es. `# Il teorema di **Bayes**`).

Attenzione: `## Bibliografia` è speciale (vedi sezione 11).

---

## 4. Testo: grassetto, corsivo, codice

```markdown
Questo è **grassetto**, questo *corsivo*, e questo `codice inline`.
```

Produce:

```latex
Questo è \textbf{grassetto}, questo \emph{corsivo}, e questo \texttt{codice inline}.
```

Il lexer gestisce correttamente gli spazi interni: `**due parole**`
diventa `\textbf{due parole}`, non si spezza. Un asterisco isolato
(es. in `2 * 3`) resta testo letterale.

---

## 5. Citazioni

```markdown
Come dimostrato in precedenza [@hoare1969], il problema è decidibile.
```

Produce:

```latex
Come dimostrato in precedenza \cite{hoare1969}, il problema è decidibile.
```

La chiave dentro `[@...]` deve corrispondere a una voce nella
sezione `## Bibliografia` (vedi sezione 11).

---

## 6. Link

```markdown
Vedi il [sito del progetto](https://example.com) per i dettagli.
```

Produce:

```latex
Vedi il \href{https://example.com}{sito del progetto} per i dettagli.
```

Richiede `\usepackage{hyperref}` (già nel preamble). Se la sintassi
non è completa (manca la parte `(url)`), il testo resta letterale.

---

## 7. Immagini

L'immagine va da sola sulla sua riga:

```markdown
![Diagramma dell'architettura](figure/arch.png)
```

Produce:

```latex
\begin{figure}[h]
  \centering
  \includegraphics[width=0.8\linewidth]{figure/arch.png}
  \caption{Diagramma dell'architettura}
\end{figure}
```

In modalità `--package`, il file immagine viene copiato in
`figures/` e il path nel `.tex` riscritto di conseguenza.

---

## 8. Liste

Liste non ordinate, un elemento per riga con `- `:

```markdown
- primo elemento
- secondo elemento con **grassetto**
- terzo elemento
```

Produce:

```latex
\begin{itemize}
  \item primo elemento
  \item secondo elemento con \textbf{grassetto}
  \item terzo elemento
\end{itemize}
```

La lista si chiude con una riga vuota o un blocco di tipo diverso.
Gli elementi possono contenere formattazione inline.

---

## 9. Blocchi di codice

Delimitati da tre backtick su righe a sé:

````markdown
```
let rec fact n =
  if n = 0 then 1 else n * fact (n - 1)
```
````

Produce:

```latex
\begin{verbatim}
let rec fact n =
  if n = 0 then 1 else n * fact (n - 1)
\end{verbatim}
```

Dentro il blocco nulla viene interpretato: niente escaping, niente
formattazione inline. È testo grezzo.

---

## 10. Tabelle

Sintassi a pipe. La prima riga è l'header, la seconda è il separatore
(ignorato), le successive sono i dati:

```markdown
| Metodo | Accuratezza | Tempo |
|--------|-------------|-------|
| SGD    | 0.91        | 12s   |
| Adam   | 0.93        | 15s   |
```

Produce (usando `booktabs`):

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

Tutte le colonne sono allineate a sinistra (`l`). La riga separatore
può usare `:` per indicare allineamento in Markdown, ma per ora viene
ignorata (vedi limiti).

---

## 11. Bibliografia

La sezione `## Bibliografia` attiva una modalità speciale. Ogni voce
è un elemento di lista che inizia con la chiave `[@chiave]`:

```markdown
## Bibliografia

- [@hoare1969] Hoare, 1969. Communicating Sequential Processes.
- [@dijkstra1975] Dijkstra, 1975. Guarded Commands, Nondeterminacy.
```

Produce:

```latex
\begin{thebibliography}{99}
  \bibitem{hoare1969} Hoare, 1969. Communicating Sequential Processes.
  \bibitem{dijkstra1975} Dijkstra, 1975. Guarded Commands, Nondeterminacy.
\end{thebibliography}
```

Le chiavi (`hoare1969`) sono quelle a cui puntano i `[@hoare1969]`
nel testo. La bibliografia è generata inline, senza `.bib` né BibTeX:
così il `.tex` è già pronto per arXiv.

---

## 12. Caratteri speciali (escaping)

I caratteri che in LaTeX hanno significato speciale vengono
automaticamente protetti nel testo normale:

| Carattere | Diventa              |
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

Quindi scrivere `il 50% dei casi` produce `il 50\% dei casi`.

---

## 13. Diagnostica e controlli

Viene effettuato il controllo del documento e segnala i problemi su stderr, 
con numero di riga, senza fermarsi al primo (stile compilatore). I messaggi diagnostici sono di due tipi:

- **warning** : l'output viene comunque generato;
- **error** : l'output è inaffidabile; l'exit code è 1.

Formato:

```
paper.md:12: error [validate]: citazione [@manca] senza voce corrispondente in ## Bibliografia
paper.md:30: warning [parser]: tabella: header ha 3 colonne ma questa riga ne ha 2
```

Controlli effettuati:

| Controllo                                   | Tipo    | Fase     |
|---------------------------------------------|---------|----------|
| Citazione `[@k]` senza voce in bibliografia | error   | validate |
| Voce di bibliografia mai citata             | warning | validate |
| Tabella con righe di lunghezza diversa      | warning | parser   |
| Blocco ``` mai chiuso                       | warning | parser   |
| Immagine referenziata ma file assente       | error   | package  |
| ORCID malformato                            | warning | meta     |
| Manca `title` / nessun autore               | warning | meta     |
| Autore senza affiliazione                   | warning | meta     |

Modalità rigorosa: con `--strict` anche i warning diventano fatali
(exit code 1). Utile in una pipeline CI per non lasciar passare un
documento con problemi:

```sh
dune exec bin/main.exe -- paper.md --package out --strict
```

---

## 14. Generare il pacchetto

Solo il `.tex`:

```sh
dune exec bin/main.exe -- paper.md -o paper.tex
```

Cartella submission-ready (`.tex` + figure copiate):

```sh
dune exec bin/main.exe -- paper.md --package submission
tar czf submission.tar.gz submission/    # pronto per l'upload
```

La cartella `submission/` conterrà `paper.tex` e, se ci sono
immagini, `figures/` con le copie.

---

