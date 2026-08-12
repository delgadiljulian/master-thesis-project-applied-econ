# Sensibilidades temporales asociativas

Esta carpeta contiene un paquete separado de efectos fijos para estudiar el
orden temporal de la asociación entre RENTS, ECI y DIVX. Sus especificaciones
son T0 (contemporánea), T1 (un rezago), T2 (promedio retrospectivo), T3
(rezagos distribuidos), T4 (adelanto placebo) y T5 (primeras diferencias).

## Límite metodológico

El paquete **no** estima cointegración, ECM, panel ARDL, VAR/VEC, Granger,
proyecciones locales, filtro Hodrick--Prescott ni respuestas a shocks. Tampoco
incluye la variable dependiente rezagada, instrumentos, GMM o una
identificación causal. Sus coeficientes describen asociaciones condicionadas
por efectos fijos de país y año, con inferencia agrupada por país.

## Relación con el TFM vigente

El núcleo que sustenta el TFM es `01_twfe_main`, con la muestra congelada de
1.044 observaciones y 49 países. Este paquete temporal se construyó sobre
muestras propias: por ejemplo, T1 usa 1.148 observaciones y 53 países. Por esa
diferencia, sus resultados no son una prueba de robustez directamente
comparable con el TWFE principal ni deben reemplazar sus tablas o conclusiones.

En la versión vigente del TFM, sólo pueden usarse como antecedentes técnicos
separados y con lenguaje asociativo. Incorporar cualquiera de estos resultados
en el texto requiere una autorización específica y, antes, una reconciliación
de muestra y especificación con el núcleo TWFE.

## Uso futuro

Si se reconsidera el paquete, la evaluación debe documentar: pregunta
económica, estimando, muestra común, pérdidas por rezagos, inferencia,
multiplicidad de contrastes y la distinción entre precedencia temporal y
causalidad. No se seleccionarán horizontes por significancia.
