# Insumo raw de FIN

`world_bank_wdi/fin_banks_wdi_input_1980_2025.csv` contiene el crédito
doméstico al sector privado otorgado por bancos como porcentaje del PIB,
publicado por los World Development Indicators (`FD.AST.PRVT.GD.ZS`).
[La ficha oficial de metadatos](https://databank.worldbank.org/metadataglossary/world-development-indicators/series/FD.AST.PRVT.GD.ZS)
define el indicador a partir de los recursos financieros provistos al sector
privado por corporaciones de depósito distintas del banco central.

La variable se interpreta como una proxy de profundidad financiera o
profundidad del crédito privado. No constituye un índice integral de desarrollo
financiero: no mide directamente acceso, eficiencia, estabilidad ni calidad de
la cartera.

La serie se conserva en su escala original. La capa raw no aplica logaritmos,
interpolaciones, imputaciones ni truncamientos. Los valores superiores a 100
son admisibles porque el saldo de crédito puede superar el PIB anual.

La captura conserva los 55 países de la muestra DRES para 1980-2025, incluidos
los faltantes, junto con el ZIP oficial, sus metadatos y un manifiesto con
hashes SHA-256.

En el período analítico 1996-2021, la serie está disponible en 1.328 de las
1.430 celdas país-año (92,87 %). Cincuenta y cuatro países tienen al menos una
observación, 40 presentan cobertura completa, 14 cobertura parcial y Nauru no
tiene datos.

La antigua captura específica de `FS.AST.PRVT.GD.ZS` dejó de ser un insumo
activo y fue trasladada a
`data/raw/_archive_unused_sources/fin_world_bank_wdi_broad_credit/`. La misma
serie amplia permanece, sin modificación, en el panel WDI compartido porque
sirve como referencia de contraste para validar la sustitución.

La descarga reproducible se implementa en
[`fin_wdi_banks_raw.py`](../../../scripts/data/raw/fin/fin_wdi_banks_raw.py).

La construcción definitiva y sus diagnósticos están documentados en
[`data/processed/fin/`](../../processed/fin/).
