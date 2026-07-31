# Plan de Trabajo Econométrico: `stata-peer-1/iv` (Variables Instrumentales / 2SLS Panel)

Este directorio contiene el flujo econométrico para la estimación por **Variables Instrumentales (2SLS en Datos de Panel)**, estructurado en 3 archivos `.do` secuenciales que abarcan **14 secciones metodológicas** en alineación con la arquitectura de `twfe`.

---

## 📂 Archivos de Código (.do)

1. 📄 **[`01_data_prep_and_diagnostics.do`](file:///C:/Users/julla/GitHub/master-thesis-project-applied-econ/scripts/econometrics/stata-peer-1/iv/01_data_prep_and_diagnostics.do)** (Parte 1 - Secciones 1 a 4)
   - **Sección 1:** Configuración del Entorno y Rutas de Trabajo (IV)
   - **Sección 2:** Carga y Validación del Panel Maestro
   - **Sección 3:** Preparación de Muestra Analítica e Instrumentos Exógenos (shocks de precios internacionales)
   - **Sección 4:** Estadísticas Descriptivas y Diagnósticos del Panel IV

2. 📄 **[`02_models_and_exports.do`](file:///C:/Users/julla/GitHub/master-thesis-project-applied-econ/scripts/econometrics/stata-peer-1/iv/02_models_and_exports.do)** (Parte 2 - Secciones 5 a 8: Agregado `RENTS`)
   - **Sección 5:** Modelo Principal de IV/2SLS: Complejidad Económica ($ECI$)
   - **Sección 6:** Modelo Complementario de IV/2SLS: Diversificación ($DIVX$)
   - **Sección 7:** Diagnósticos de Instrumentos (F de primera etapa / Stock-Yogo, Sargan/Basmann y Hausman)
   - **Sección 8:** Exportación de Resultados y Tablas Principales a LaTeX (`.tex`) y Texto (`.txt`)

3. 📄 **[`03_resource_disaggregation.do`](file:///C:/Users/julla/GitHub/master-thesis-project-applied-econ/scripts/econometrics/stata-peer-1/iv/03_resource_disaggregation.do)** (Parte 3 - Secciones 9 a 14: Desagregado Hidrocarburos vs. Minería + Carbón)
   - **Sección 9:** Diseño de la Desagregación de RENTS en IV ($RENTS^{OIL+GAS}$ vs $RENTS^{MINING}$)
   - **Sección 10:** Preparación y Diagnósticos de Instrumentos Específicos por Componente
   - **Sección 11:** Modelos IV/2SLS Desagregados con ECI
   - **Sección 12:** Modelos IV/2SLS Desagregados con DIVX
   - **Sección 13:** Estabilidad, Diagnósticos de Validez de Instrumentos por Componente
   - **Sección 14:** Exportación y Cierre de la Desagregación IV (Tablas LaTeX y Figuras)

---

## 📊 Estructura de Salidas (`outputs/econometrics/stata-peer-1/iv/`)

- `00_design/`
- `01_sample/`
- `02_diagnostics/`
- `03_eci/`
- `04_divx/`
- `05_stability/`
- `06_resource_disaggregation/`
- `07_final/`
- `logs/`
