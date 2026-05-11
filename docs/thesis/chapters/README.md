# Thesis chapters

This folder contains the modular source files used by `../TFM.tex`.
Each chapter lives in its own folder so chapter text, local notes, temporary
metadata, and future chapter-specific assets do not clutter the main thesis
directory.

## How synchronization works

`../TFM.tex` is the master document. It loads each chapter with `\subfile{...}`:

```tex
\subfile{chapters/01-06-introduction-and-research-design/chapter.tex}
\subfile{chapters/07-theoretical-framework/chapter.tex}
\subfile{chapters/08-empirical-literature/chapter.tex}
\subfile{chapters/09-methodology/chapter.tex}
\subfile{chapters/10-data-and-variables/chapter.tex}
\subfile{chapters/11-results/chapter.tex}
\subfile{chapters/12-conclusions/chapter.tex}
\subfile{chapters/bibliography/bibliography.tex}
\subfile{chapters/appendices/appendices.tex}
```

When a chapter file changes, recompiling `../TFM.tex` automatically pulls the
updated content into the full thesis PDF. There is no need to copy and paste
finished chapters into the master file.

## Chapter files

Current source files:

- `01-06-introduction-and-research-design/chapter.tex`
- `07-theoretical-framework/chapter.tex`
- `08-empirical-literature/chapter.tex`
- `09-methodology/chapter.tex`
- `10-data-and-variables/chapter.tex`
- `11-results/chapter.tex`
- `12-conclusions/chapter.tex`
- `bibliography/bibliography.tex`
- `appendices/appendices.tex`

Each source file is a `subfiles` document:

```tex
\documentclass[../../TFM.tex]{subfiles}

\begin{document}
% chapter content
\end{document}
```

This lets a chapter compile on its own while still inheriting the preamble,
formatting, bibliography settings, and shared commands from `../TFM.tex`.

## Compiling

Compile the full thesis from `docs/thesis`:

```powershell
xelatex TFM.tex
biber TFM
xelatex TFM.tex
xelatex TFM.tex
```

Compile an individual chapter from its own folder:

```powershell
xelatex chapter.tex
biber chapter
xelatex chapter.tex
xelatex chapter.tex
```

For `appendices` and `bibliography`, use their actual file names:

```powershell
xelatex appendices.tex
biber appendices
xelatex appendices.tex
xelatex appendices.tex
```

```powershell
xelatex bibliography.tex
biber bibliography
xelatex bibliography.tex
xelatex bibliography.tex
```

## Shared assets

Shared figures remain in `../figures`. From a chapter subfile, reference them
with `\subfix{../../figures/...}` so the same path works both when compiling
the chapter alone and when compiling `../TFM.tex`.

Example:

```tex
\includegraphics[width=\textwidth]{\subfix{../../figures/example_figure}}
```

## Git hygiene

Commit source files such as `.tex`, `.bib`, `.md`, scripts, and intentional
figures/tables. Do not commit LaTeX build artifacts such as `.aux`, `.bbl`,
`.bcf`, `.blg`, `.log`, `.out`, `.run.xml`, `.synctex.gz`, or generated PDFs
unless there is a deliberate reason. These patterns are already covered by the
repository `.gitignore`.
