# Plan de Trabajo Econométrico: `stata-peer-1` (Peer 1 - Antigravity)

Este directorio contiene el flujo econométrico modular de Peer 1 (Antigravity) en Stata 17 MP, dividido en dos scripts `.do` secuenciales e independientes.

---

## 📂 Archivos de Código (.do)

1. 📄 **[`01_data_prep_and_diagnostics.do`](file:///c:/Users/julla/GitHub/master-thesis-project-applied-econ/scripts/econometrics/stata-peer-1/01_data_prep_and_diagnostics.do)** (Parte 1)
   - **Sección 1:** Configuración del Entorno y Rutas de Trabajo (`outputs/econometrics/stata-peer-1/`)
   - **Sección 2:** Carga y Validación del Panel Maestro (`browse`, `country_id` en Columna 3)
   - **Sección 3:** Preparación de Datos y Muestras Analíticas (`master_panel_sample.dta`, cobertura por país)
   - **Sección 4:** Estadísticas Descriptivas y Diagnósticos Avanzados (Reportes CSV de descriptivos, variación panel, correlaciones y VIF *within*)

2. 📄 **[`02_models_and_exports.do`](file:///c:/Users/julla/GitHub/master-thesis-project-applied-econ/scripts/econometrics/stata-peer-1/02_models_and_exports.do)** (Parte 2)
   - **Sección 5:** Modelo Principal: ECI (TWFE) [Ecuación 9.17]
   - **Sección 6:** Modelo Complementario: DIVX (TWFE) [Ecuación 9.58]
   - **Sección 7:** Estabilidad, Efectos Marginales (`margins`) y Desagregación por Recursos
   - **Sección 8:** Exportación de Resultados y Tablas a LaTeX (`.tex`) y Texto (`.txt`)

---

## 🏃 Modo de Ejecución en Stata

```stata
* Ejecutar la Parte 1 (Preparación de datos y diagnósticos)
do "scripts/econometrics/stata-peer-1/01_data_prep_and_diagnostics.do"

* Ejecutar la Parte 2 (Estimación de modelos y exportación)
do "scripts/econometrics/stata-peer-1/02_models_and_exports.do"
```
