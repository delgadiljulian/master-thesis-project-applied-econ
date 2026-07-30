#!/usr/bin/env bash
set -euo pipefail

# Ejecutar comando de configuración del entorno
echo "Creating thesis project directory structure..."

# Ejecutar comando de configuración del entorno
mkdir -p data/raw
mkdir -p data/processed

# Ejecutar comando de configuración del entorno
mkdir -p docs/drafts/summary
mkdir -p docs/drafts/theoretical-notes
mkdir -p docs/literature/colombia-sgr
mkdir -p docs/literature/resource-dependent-economies
mkdir -p docs/literature/student-theses
mkdir -p docs/proposal/figures
mkdir -p docs/thesis/figures

# Ejecutar comando de configuración del entorno
mkdir -p outputs/figures/literature
mkdir -p outputs/figures/original
mkdir -p outputs/tables

# Ejecutar comando de configuración del entorno
mkdir -p scripts

# Ejecutar comando de configuración del entorno
touch data/raw/.gitkeep
touch data/processed/.gitkeep
touch outputs/.gitkeep
touch outputs/figures/.gitkeep
touch outputs/tables/.gitkeep

# Ejecutar comando de configuración del entorno
echo "Thesis project structure is ready."
