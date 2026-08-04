# Índice de resultados econométricos agregados

Generado por 04_twfe_full.do el  4 Aug 2026.

Este paquete corresponde a los modelos agregados de RENTS. No contiene la futura desagregación hidrocarburos-minería.

## Resultados finales

- table_eci_divx_twfe.tex: tabla LaTeX conjunta de los modelos principales.
- table_eci_divx_twfe.txt: versión en texto plano para revisión.
- table_per_capita_transformation_sensitivity.tex: sensibilidad LaTeX de ln(1+x) frente a niveles per cápita.
- table_per_capita_transformation_sensitivity.txt: versión de texto de la sensibilidad de transformación.
- final_model_coefficients.csv: coeficientes e incertidumbre de ECI y DIVX.
- final_model_summaries.csv: muestra, cobertura y ajuste de ambos modelos.
- final_joint_tests.csv: pruebas conjuntas por canal y efectos de año.
- evidence_classification.csv: clasificación de evidencia central, complementaria y no concluyente.

## Estabilidad y efectos marginales

- final_rents_marginal_effects_by_inst.csv: asociación marginal de RENTS en P10, P25, P50, P75 y P90 de INST.
- final_influential_observation_sensitivity.csv: comparación con exclusión de observaciones alertadas.
- final_leave_one_country_out_summary.csv: estabilidad al retirar un país por vez.
- final_wild_cluster_bootstrap.csv: inferencia bootstrap agrupada por país.
- final_resource_coefficient_equality.csv: igualdad entre petróleo, gas y carbón.
- final_per_capita_transformation_sensitivity.csv: comparación de ln(1+x) con OILPC, GASPC y COALPC en niveles.
- figure_rents_marginal_effects_eci_divx.pdf: figura comparada para LaTeX.
- figure_rents_marginal_effects_eci_divx.png: figura comparada para revisión visual.

## Reglas de interpretación

1. Los coeficientes describen asociaciones condicionadas dentro de los países; no identifican efectos causales.
2. RENTS debe interpretarse junto con los efectos marginales porque el modelo incluye RENTS x INST.
3. La interacción institucional es no concluyente en ambos modelos.
4. Las sensibilidades no sustituyen las especificaciones ECI_TWFE_MAIN y DIVX_TWFE_MAIN.
5. La sensibilidad de forma funcional solo cambia OILPC, GASPC y COALPC; RENTS permanece agregado.
6. HHI se excluye de DIVX porque DIVX = 1 - HHI.

