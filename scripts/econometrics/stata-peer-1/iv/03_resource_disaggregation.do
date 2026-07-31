* ==============================================================================
* PROYECTO: Transición Productiva y Complejidad Económica en Países Extractivos
* ESQUEMA METODOLÓGICO: Variables Instrumentales / 2SLS en Datos de Panel
* ARCHIVO: 03_resource_disaggregation.do
* PROPÓSITO: Esqueleto estructural para la estimación IV/2SLS desagregada
*            por tipo de recurso (Hidrocarburos vs. Minería). Secciones 9 a 14.
* AUTOR: Antigravity (Peer 1)
* FECHA: 2026-07-31
* ==============================================================================

version 17.0
clear all
set more off
capture log close _all

* ------------------------------------------------------------------------------
* 9. Diseño de la Desagregación de RENTS en IV (OIL+GAS vs MINING)
* ------------------------------------------------------------------------------

* ------------------------------------------------------------------------------
* 10. Preparación y Diagnósticos de Instrumentos Específicos por Componente
* ------------------------------------------------------------------------------

* ------------------------------------------------------------------------------
* 11. Modelos IV/2SLS Desagregados con ECI
* ------------------------------------------------------------------------------

* ------------------------------------------------------------------------------
* 12. Modelos IV/2SLS Desagregados con DIVX
* ------------------------------------------------------------------------------

* ------------------------------------------------------------------------------
* 13. Estabilidad y Diagnósticos de Validez de Instrumentos por Componente
* ------------------------------------------------------------------------------

* ------------------------------------------------------------------------------
* 14. Exportación y Cierre de la Desagregación IV (Tablas LaTeX y Figuras)
* ------------------------------------------------------------------------------
