# Comparación de las variantes completas de M3

## 1. Alcance

Este documento compara cuatro especificaciones TWFE completas sobre la misma
muestra de 1.044 observaciones y 49 países:

1. `M3_AGG`: rentas extractivas agregadas.
2. `M3_OG`: rentas de petróleo y gas.
3. `M3_MIN`: rentas de minería y carbón.
4. `M3_SIM`: petróleo y gas y minería y carbón incorporados simultáneamente.

Todos los modelos incluyen efectos fijos por país y año y errores estándar
agrupados por país. Las comparaciones son descriptivas e inferenciales dentro
de un diseño observacional; no identifican efectos causales.

## 2. Comparabilidad y ajuste

| Resultado | M3_AGG | M3_OG | M3_MIN | M3_SIM |
|---|---:|---:|---:|---:|
| ECI: R² within | 0,1523 | 0,1444 | 0,1502 | 0,1566 |
| DIVX: R² within | 0,3119 | 0,3259 | 0,2707 | 0,3270 |

Las diferencias de ajuste para ECI son reducidas. Para DIVX, M3_OG reproduce
casi todo el ajuste del modelo simultáneo y supera al modelo agregado, mientras
M3_MIN presenta un ajuste menor. El R² within se utiliza solamente como medida
descriptiva de ajuste y no como criterio para seleccionar resultados por
significancia ni como evidencia causal.

## 3. Rentas e interacción institucional

### 3.1. ECI

- En M3_AGG, RENTS presenta un coeficiente de -0,009795 (`p = 0,023`).
- En M3_OG, RENTS_OIL_GAS presenta -0,005604 (`p = 0,335`).
- En M3_MIN, RENTS_MINING presenta -0,012179 (`p = 0,003`).
- En M3_SIM, RENTS_OIL_GAS presenta -0,007254 (`p = 0,212`) y
  RENTS_MINING -0,013597 (`p = 0,001`).

La asociación negativa con ECI se concentra empíricamente en minería y carbón:
el coeficiente minero conserva signo, magnitud y precisión tanto cuando se
estima como variante alternativa como cuando ambos componentes entran de forma
simultánea. La prueba conjunta de RENTS_MINING y su interacción en M3_SIM arroja
`p = 0,002`, mientras la correspondiente a hidrocarburos arroja `p = 0,291`.

Sin embargo, no se rechaza que los coeficientes directos de ambos componentes
sean iguales (`p = 0,325`), ni la restricción conjunta que recupera el modelo
agregado (`p = 0,332`). Por tanto, es válido afirmar que la evidencia negativa
precisa aparece en el componente minero, pero no que su coeficiente sea
estadísticamente mayor en valor absoluto que el de petróleo y gas.

### 3.2. DIVX

- En M3_AGG, RENTS presenta -0,003536 (`p = 0,009`).
- En M3_OG, RENTS_OIL_GAS presenta -0,004709 (`p = 0,001`).
- En M3_MIN, RENTS_MINING presenta -0,000469 (`p = 0,801`).
- En M3_SIM, RENTS_OIL_GAS presenta -0,004849 (`p = 0,001`) y
  RENTS_MINING -0,001413 (`p = 0,459`).

La asociación negativa con DIVX se concentra empíricamente en petróleo y gas.
El bloque de hidrocarburos es conjuntamente significativo en M3_SIM
(`p < 0,001`), mientras el bloque minero no lo es (`p = 0,749`). La restricción
conjunta del modelo agregado se rechaza (`p = 0,018`), lo que indica que la
desagregación aporta información para DIVX.

La igualdad de los coeficientes directos no se rechaza al 5 % (`p = 0,108`).
En consecuencia, tampoco debe presentarse la diferencia de significancia como
una prueba concluyente de que los efectos directos sean distintos.

### 3.3. Interacciones

Ninguna interacción entre rentas y calidad institucional es individualmente
significativa en las variantes completas. En M3_SIM tampoco son conjuntamente
significativas para ECI (`p = 0,340`) ni para DIVX (`p = 0,599`). La evidencia
no permite afirmar que INST modere con precisión estadística la asociación de
las rentas con los dos resultados.

## 4. Canales comunes

### 4.1. ECI

El resultado más estable corresponde al canal de estructura exportadora:

- HHI es negativo y significativo en los cuatro M3; sus coeficientes se sitúan
  aproximadamente entre -0,535 y -0,598.
- PEXP es negativo, cercano a -0,0042, y significativo en los cuatro modelos.
- FEXP es negativo, entre aproximadamente -0,0068 y -0,0073, y significativo
  en los cuatro modelos.
- El bloque estructural es conjuntamente significativo en M3_AGG, M3_OG y
  M3_MIN (`p <= 0,0011`). M3_SIM no exporta esa prueba conjunta, aunque los tres
  coeficientes estructurales conservan allí el mismo signo y significancia
  individual.

INST conserva signo positivo y significancia únicamente al 10 % en las cuatro
especificaciones (`p` entre aproximadamente 0,057 y 0,085). Debe describirse
como evidencia débil o marginal, no como un resultado robusto al 5 %.

Los controles de abundancia per cápita, macroeconomía, capacidades productivas
y condiciones económicas y financieras mantienen signos generalmente estables
pero no presentan precisión individual ni conjunta para ECI. La ausencia de
significancia no justifica ocultarlos: forman parte de la especificación teórica
y permiten observar que el patrón estructural permanece al controlar todos los
canales simultáneamente.

### 4.2. DIVX

Tres resultados se mantienen con signo y significancia al 5 % en los cuatro
M3:

- PEXP: asociación positiva, alrededor de 0,0015.
- HUMCAP: asociación positiva, aproximadamente entre 0,107 y 0,112.
- log(GDPPC): asociación negativa, aproximadamente entre -0,141 y -0,150.

Los bloques de estructura exportadora, capacidades productivas y controles
económicos y financieros son conjuntamente significativos en M3_AGG, M3_OG y
M3_MIN. Esta estabilidad confirma que la lectura de DIVX no debe reducirse al
coeficiente de las rentas.

NET conserva signo negativo en los cuatro modelos, pero su precisión es
sensible: es significativo al 5 % en M3_AGG, al 10 % en M3_OG y M3_SIM, y no
resulta significativo en M3_MIN. GOVCONS conserva signo positivo y evidencia
al 10 % en tres variantes, sin alcanzar el 5 %. FIN también es positivo, pero
su precisión es todavía más débil. Estos resultados deben presentarse con
cautela.

La renta carbonífera per cápita conserva signo negativo para DIVX, pero solo es
significativa al 5 % en M3_OG y al 10 % en M3_SIM. No constituye un resultado
estable en las cuatro especificaciones.

## 5. Lectura conjunta por bloques

| Resultado | Bloque estable | Bloques sin evidencia conjunta estable |
|---|---|---|
| ECI | Estructura exportadora | Abundancia, macroeconomía, capacidades y controles económicos |
| DIVX | Estructura exportadora, capacidades productivas y controles económicos | Abundancia y macroeconomía |

El bloque institucional depende del componente utilizado: para ECI es
significativo en M3_MIN, pero no en M3_AGG ni M3_OG; para DIVX es significativo
en M3_AGG y M3_OG, pero no en M3_MIN. Este patrón responde principalmente al
término directo de rentas correspondiente, no a una interacción institucional
precisa.

## 6. Límites interpretativos

1. No confundir una diferencia de significancia con una diferencia
   estadísticamente significativa entre coeficientes.
2. No presentar las asociaciones como causales.
3. No interpretar el coeficiente constitutivo de rentas como un efecto universal:
   con interacción, corresponde a `INST = 0`.
4. Para otros niveles de INST, el efecto marginal debe calcularse combinando el
   término directo y la interacción.
5. No seleccionar el modelo por R² within ni eliminar variables no
   significativas.
6. M3_OG y M3_MIN son especificaciones alternativas completas; M3_SIM es el
   contraste que permite mantener constante el otro componente.
7. El modelo agregado continúa siendo el punto de referencia; la desagregación
   muestra dónde se concentra la evidencia, pero no reemplaza por sí sola la
   estructura general del TFM.

## 7. Implicación para la futura redacción

Cuando se autorice la modificación del TFM, cada componente puede recibir una
subsección y una tabla completa. La interpretación deberá comenzar por los
patrones de ECI y DIVX y recorrer todos los canales comunes. Los coeficientes de
rentas y sus interacciones serán una parte del análisis, no la única evidencia
presentada. M3_SIM puede conservarse como contraste complementario para sostener
las cautelas sobre diferencias entre componentes.
