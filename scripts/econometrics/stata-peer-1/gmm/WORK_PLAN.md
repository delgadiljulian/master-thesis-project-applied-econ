# Plan de Trabajo Econométrico: `stata-peer-1/gmm` (System GMM / Panel Dinámico)

Este directorio contiene el flujo econométrico para la estimación de **GMM Dinámico en Datos de Panel (Arellano-Bond / Blundell-Bond System GMM)**, estructurado en 3 archivos `.do` secuenciales que abarcan **14 secciones metodológicas** en alineación con la arquitectura de `twfe`.

---

## 📂 Archivos de Código (.do)

1. 📄 **[`01_data_prep_and_diagnostics.do`](file:///C:/Users/julla/GitHub/master-thesis-project-applied-econ/scripts/econometrics/stata-peer-1/gmm/01_data_prep_and_diagnostics.do)** (Parte 1 - Secciones 1 a 4)
   - **Sección 1:** Configuración del Entorno y Rutas de Trabajo (GMM)
   - **Sección 2:** Carga y Validación del Panel Maestro
   - **Sección 3:** Preparación de Muestra Analítica y Rezagos Dinámicos ($ECI_{i,t-1}, DIVX_{i,t-1}$)
   - **Sección 4:** Estadísticas Descriptivas y Diagnósticos del Panel Dinámico

2. 📄 **[`02_models_and_exports.do`](file:///C:/Users/julla/GitHub/master-thesis-project-applied-econ/scripts/econometrics/stata-peer-1/gmm/02_models_and_exports.do)** (Parte 2 - Secciones 5 a 8: Agregado `RENTS`)
   - **Sección 5:** Modelo Principal de GMM Dinámico: Complejidad Económica ($ECI$) (`xtabond2` / `xtdpdsys`)
   - **Sección 6:** Modelo Complementario de GMM Dinámico: Diversificación ($DIVX$)
   - **Sección 7:** Diagnósticos de Especificación (Sargan/Hansen) y Autocorrelación ($AR(1)$ / $AR(2)$)
   - **Sección 8:** Exportación de Resultados y Tablas Principales a LaTeX (`.tex`) y Texto (`.txt`)

3. 📄 **[`03_resource_disaggregation.do`](file:///C:/Users/julla/GitHub/master-thesis-project-applied-econ/scripts/econometrics/stata-peer-1/gmm/03_resource_disaggregation.do)** (Parte 3 - Secciones 9 a 14: Desagregado Hidrocarburos vs. Minería + Carbón)
   - **Sección 9:** Diseño de la Desagregación de RENTS en GMM ($RENTS^{OIL+GAS}$ vs $RENTS^{MINING}$)
   - **Sección 10:** Preparación y Diagnósticos de los Componentes Desagregados para GMM
   - **Sección 11:** Modelos GMM Dinámicos Desagregados con ECI
   - **Sección 12:** Modelos GMM Dinámicos Desagregados con DIVX
   - **Sección 13:** Estabilidad, Diagnósticos de Instrumentos y Efectos Marginales por Componente
   - **Sección 14:** Exportación y Cierre de la Desagregación GMM (Tablas LaTeX y Figuras)

---

## 📊 Estructura de Salidas (`outputs/econometrics/stata-peer-1/gmm/`)

- `00_design/`
- `01_sample/`
- `02_diagnostics/`
- `03_eci/`
- `04_divx/`
- `05_stability/`
- `06_resource_disaggregation/`
- `07_final/`
- `logs/`
