---
title: "A good title"
authors:
  - name:  "Pippo"
    affil: "Università di Torino"
    orcid: "0000-0000-1111-1111"
    email: "Pippo@unito.it"
  - name:  "Pippo Turing"
    affil: "University of Cambridge"
    orcid: "0000-0000-9898-00000"
abstract: |
  A good abstract
keywords: [keyword1, keyword2, keyword3]
arxiv_category: cs.LG
date: 2026-05-29
---

# Titolo del documento

Questo è un paragrafo con **grassetto**, *corsivo*, `codice` e una citazione [@hoare1969].

Ecco un link: [Sito](https://example.com)

E un'immagine:

![Diagramma](immagine.png)

- primo elemento
- secondo elemento
- terzo elemento

Una tabella di risultati:

| Metodo | Accuratezza | Tempo |
|--------|-------------|-------|
| SGD    | 0.91        | 12s   |
| Adam   | 0.93        | 15s   |

Un blocco di codice:

```
let rec fact n =
  if n = 0 then 1 else n * fact (n - 1)
```

## Bibliografia

- [@hoare1969] Hoare, 1969. Communicating Sequential Processes.
- [@dijkstra1975] Dijkstra, 1975. Guarded Commands, Nondeterminacy.
