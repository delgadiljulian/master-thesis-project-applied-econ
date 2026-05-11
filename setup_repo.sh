#!/usr/bin/env bash
set -euo pipefail

echo "Creating thesis project directory structure..."

mkdir -p data/raw
mkdir -p data/processed

mkdir -p docs/drafts/summary
mkdir -p docs/drafts/theoretical-notes
mkdir -p docs/literature/colombia-sgr
mkdir -p docs/literature/resource-dependent-economies
mkdir -p docs/literature/student-theses
mkdir -p docs/proposal/figures
mkdir -p docs/thesis/figures

mkdir -p outputs/figures/literature
mkdir -p outputs/figures/original
mkdir -p outputs/tables

mkdir -p scripts

touch data/raw/.gitkeep
touch data/processed/.gitkeep
touch outputs/.gitkeep
touch outputs/figures/.gitkeep
touch outputs/tables/.gitkeep

echo "Thesis project structure is ready."
