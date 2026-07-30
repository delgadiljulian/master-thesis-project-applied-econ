# Plan de Trabajo Econométrico: `stata-peer-1` (Peer 1 - Antigravity)

Este directorio contiene el flujo econométrico modular de Peer 1 (Antigravity) en Stata 17 MP, estructurado en tres scripts `.do` secuenciales con alineación 1:1 respecto a `stata-peer-2` (Codex).

---

## 📂 Archivos de Código (.do)

1. 📄 **[`01_data_prep_and_diagnostics.do`](file:///c:/Users/julla/GitHub/master-thesis-project-applied-econ/scripts/econometrics/stata-peer-1/01_data_prep_and_diagnostics.do)** (Parte 1 - Secciones 1 a 4)
   - **Sección 1:** Configuración del Entorno y Rutas de Trabajo (`outputs/econometrics/stata-peer-1/`)
   - **Sección 2:** Carga y Validación del Panel Maestro (`browse`, `country_id` en Columna 3)
   - **Sección 3:** Preparación de Datos y Muestras Analíticas (`master_panel_sample.dta`, asimetría $\ln(1+x)$, cobertura por país)
   - **Sección 4:** Estadísticas Descriptivas y Diagnósticos Avanzados (Descriptivos, variación panel, correlaciones, VIF *within*, pruebas de error Wald/Wooldridge/Pesaran y observaciones influyentes)

2. 📄 **[`02_models_and_exports.do`](file:///c:/Users/julla/GitHub/master-thesis-project-applied-econ/scripts/econometrics/stata-peer-1/02_models_and_exports.do)** (Parte 2 - Secciones 5 a 8: Agregado `RENTS`)
   - **Sección 5:** Modelo Principal: ECI (TWFE) [Ecuación 9.17]
   - **Sección 6:** Modelo Complementario: DIVX (TWFE) [Ecuación 9.58]
   - **Sección 7:** Estabilidad, Efectos Marginales (`margins`), Jackknife (49 países) e Inferencia Bootstrap (`boottest`)
   - **Sección 8:** Exportación de Resultados y Tablas Principales a LaTeX (`.tex`) y Texto (`.txt`)

3. 📄 **[`03_resource_disaggregation.do`](file:///c:/Users/julla/GitHub/master-thesis-project-applied-econ/scripts/econometrics/stata-peer-1/03_resource_disaggregation.do)** (Parte 3 - Secciones 9 a 14: Desagregado Hidrocarburos vs. Minería + Carbón)
   - **Sección 9:** Diseño de la Desagregación de RENTS (`RENTS_OIL_GAS` vs `RENTS_MINING`)
   - **Sección 10:** Preparación y Diagnósticos de los Componentes
   - **Sección 11:** Modelos Desagregados con ECI (TWFE)
   - **Sección 12:** Modelos Desagregados con DIVX (TWFE)
   - **Sección 13:** Estabilidad y Efectos Marginales por Componente
   - **Sección 14:** Exportación y Cierre de la Desagregación (Tablas LaTeX y Figuras)

---

## 🏃 Modo de Ejecución en Stata / CMD

```powershell
# Ejecutar todo el flujo mediante el controlador de lotes sin contaminar la raíz:
.\scripts\econometrics\stata-peer-1\run_stata_peer_1.cmd -Stage all
```

```stata
* O ejecutar manualmente desde la consola de Stata:
do "scripts/econometrics/stata-peer-1/01_data_prep_and_diagnostics.do"
do "scripts/econometrics/stata-peer-1/02_models_and_exports.do"
do "scripts/econometrics/stata-peer-1/03_resource_disaggregation.do"
```
