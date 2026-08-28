# Regla de inferencia del núcleo TWFE

La inferencia principal de ECI y DIVX usa errores estándar agrupados por país:
`vce(cluster country_id)`. Esta decisión responde a heterocedasticidad y
autocorrelación dentro de los países, y se complementa con wild cluster
bootstrap de 9.999 repeticiones para los términos focales.

Los efectos fijos de año absorben shocks comunes. En los diagnósticos vigentes
de residuos con efectos de año, Pesaran CD no rechaza independencia
transversal para ECI (p = 0,663) ni DIVX (p = 0,442). Por tanto,
Driscoll--Kraay no sustituye la inferencia principal.

El archivo `09_panel_specification_validation.do` incorpora una sensibilidad
Driscoll--Kraay acotada sobre la misma muestra de 1.044 observaciones. Utiliza
`lag(2)`, derivado de la regla de Newey--West para los 23 años efectivos, y
reporta todos los coeficientes sustantivos. Su función es evaluar la sensibilidad
de la incertidumbre; no seleccionar variables ni alterar los coeficientes FE.

La jerarquía aprobada es: agrupación por país como inferencia principal, wild
cluster bootstrap de 9.999 repeticiones para los términos focales y
Driscoll--Kraay como sensibilidad secundaria. PCSE no se activa porque no existe
una necesidad diagnóstica distinta que justifique otro método de covarianza.
