# Regla de inferencia del núcleo TWFE

La inferencia principal de ECI y DIVX usa errores estándar agrupados por país:
`vce(cluster country_id)`. Esta decisión responde a heterocedasticidad y
autocorrelación dentro de los países, y se complementa con wild cluster
bootstrap de 9.999 repeticiones para los términos focales.

Los efectos fijos de año absorben shocks comunes. En los diagnósticos vigentes
de residuos con efectos de año, Pesaran CD no rechaza independencia
transversal para ECI (p = 0,663) ni DIVX (p = 0,442). Por tanto, Driscoll--Kraay
no se activa automáticamente ni sustituye la inferencia principal.

Una eventual sensibilidad Driscoll--Kraay requerirá una decisión separada:
diagnóstico que la motive, especificación, regla de rezagos, muestra,
interpretación secundaria y reconciliación con los errores agrupados. No debe
alterar las tablas principales ni la lectura asociativa del TFM.
