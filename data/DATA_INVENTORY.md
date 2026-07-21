# Data Inventory

Checklist of variables required by the thesis methodology and where their raw
inputs should live. Folder names follow the model variables rather than the data
provider. For abbreviation meanings, see `VARIABLE_GLOSSARY.md`.

| Variable | Status | Raw folder | Processed folder | Source / note |
| --- | --- | --- | --- |
| `DRES` | Available | `data/raw/atlas/sitc_rev2_trade/`, `data/raw/dres/world_bank_wdi/` | `data/processed/dres/` | Built from Atlas SITC Rev. 2 product exports for 1990-1995. The denominator is merchandise exports, including the unclassified merchandise residual `XXXX` and excluding services. The numerator covers SITC 3, 27, 28 and 68, natural precious stones 6672-6673, and non-monetary gold 9710; codes 2711, 2786, 2820, 2881, 2882, 3510, 6671 and 6674 are excluded because they do not represent direct extraction of non-renewable subsoil resources. The validated nested samples contain 55 countries at 20%, 49 at 30% and 42 at 40%. WDI inputs are retained only for validation and population robustness diagnostics. |
| `ECI` | Available and processed | `data/raw/eci/atlas/` | `data/processed/eci/atlas/` | Atlas of Economic Complexity / Harvard Growth Lab. `scripts/data/eci/eci_atlas_data.R` constructs the complete 55-country grid for 1996-2022 and writes identical CSV and Stata panels. The main `eci_hs92` series is observed for 44 countries: 43 have all 27 years, South Africa has 2000-2022, and 11 countries have no ECI observations. Missing values remain explicit and are not imputed. |
| `HHI`, `DIVX = 1 - HHI` | Available | `data/raw/atlas/sitc_rev2_trade/` | `data/processed/hhi_divx/` | `scripts/data/hhi_divx/hhi_divx_atlas.R` processes the 55 countries in the DRES 20% sample for 1990-2022. The validated panel contains 1,815 country-years, with no duplicate keys and complete HHI-DIVX coverage. HHI is calculated from four-digit SITC product shares in classified merchandise exports; the five service categories and the heterogeneous residual `XXXX` are excluded from the product vector. `XXXX` is reported separately as a classification-coverage diagnostic and as a sensitivity calculation that treats it as one category: 192 country-years exceed a 10% unclassified merchandise share. |
| `RENTS` | Raw inputs available through 2021 | `data/raw/world_bank_wdi/` | `data/processed/rents/` | The extractive measure must sum only oil, natural-gas, coal and mineral rents. Forest rents and the WDI total-rents indicator are excluded from the downloader and will not enter the thesis panel. WDI does not publish the four extractive rent series for 2022. |
| `INST` | Raw inputs available | `data/raw/inst/world_bank_wgi/` | `data/processed/inst/` | Worldwide Governance Indicators for control of corruption, rule of law and government effectiveness. All 55 DRES countries are represented, but WGI has structural gaps in 1997, 1999 and 2001. Construct the aggregate institutional index without treating those unpublished years as failed downloads. |
| `RENTS x INST` | Derived | No raw folder | No standalone folder | Construct after `RENTS` and `INST`. |
| `OILPC`, `GASPC`, `COALPC` | Exact raw inputs available through 2021 | `data/raw/world_bank_wdi/`, `data/raw/oilpc_gaspc_coalpc/` | `data/processed/oilpc_gaspc_coalpc/` | The shared WDI download contains resource-specific rent shares, population, and GDP in current and constant US dollars. These inputs are sufficient to construct real rents per capita. WDI does not publish the resource-rent components for 2022; the existing IEA, JODI and OWID files remain possible production-based robustness sources. |
| `PEXP`, `FEXP` | Shared raw trade inputs available; construction pending | `data/raw/atlas/sitc_rev2_trade/` | `data/processed/pexp_fexp/` | Use the common Atlas SITC Rev. 2 country-year-product exports to classify primary products and fuels and calculate their shares of total exports. Do not duplicate the raw trade files under `data/raw/pexp_fexp/`. |
| `VOL` | Raw price inputs available; definition pending | `data/raw/vol/world_bank_pink_sheet/`, `data/raw/atlas/sitc_rev2_trade/` | `data/processed/vol/world_bank_pink_sheet/` | The Pink Sheet supplies international commodity prices and Atlas trade data can supply country exposure weights. No additional raw download is required until the thesis chooses between a constructed commodity-price exposure and an external terms-of-trade index. |
| `RER` | Main and robustness raw inputs available | `data/raw/pwt/`, `data/raw/rer/pwt_wdi/`, `data/raw/world_bank_wdi/` | `data/processed/rer/` | The main measure will be `log(pl_gdpo)` from PWT 11.0. The raw `pl_gdpo` series covers 1,404 of 1,485 country-years (94.5%); 52 countries have complete 1996-2022 series and Libya, Nauru and Papua New Guinea have no PWT observations. WDI `PX.REX.REER` is retained as a robustness measure and covers 750 country-years (50.5%) across 28 countries. |
| `HUMCAP` | Updated raw source available | `data/raw/pwt/`, `data/raw/humcap/pwt/`, `data/raw/world_bank_wdi/` | `data/processed/humcap/` | PWT 11.0 is stored once as a shared source because it supplies both `HUMCAP` and `RER`. It replaces the outdated 1950-2019 vintage and covers 1950-2023. Its `hc` series is complete for 47 of the 55 DRES countries during 1996-2022; eight countries have no PWT human-capital observations. The WDI HCI alternative remains structurally sparse. |
| `INNOV` | Main and robustness raw inputs available | `data/raw/world_bank_wdi/`, `data/raw/innov/world_bank_wdi/` | `data/processed/innov/` | The main measure will be `log(1 + scientific articles per million inhabitants)` using WDI `IP.JRN.ARTC.SC` and population. Articles cover all 1,485 country-years and all 55 DRES countries during 1996-2022. Resident patents per million are retained for robustness, with 662 observations (44.6%) across 43 countries; R&D expenditure remains a non-priority alternative with 482 observations (32.5%). |
| `NET` | Raw input available | `data/raw/world_bank_wdi/` | `data/processed/net/` | Internet users as a percentage of population are available for all 55 countries, covering 1,431 of 1,485 country-years (96.4%); 40 countries have complete 1996-2022 series. |
| `LOG_GDPPC` | Correct PPP raw input available | `data/raw/world_bank_wdi/`, `data/raw/gdppc/world_bank_wdi/` | `data/processed/gdppc/` | The shared download adds `NY.GDP.PCAP.PP.KD`, matching the methodology's constant-PPP definition. It covers 53 countries completely; Venezuela and Yemen have no observations. The older local series uses constant US dollars rather than PPP and should not be the official model input. |
| `FISC` | Candidate raw inputs available; definition pending | `data/raw/world_bank_wdi/`, `data/raw/fisc/world_bank_wdi/` | `data/processed/fisc/` | Government consumption and tax revenue were downloaded as candidate proxies. Government consumption covers 81.5% of the main grid and tax revenue 46.4%. A country-year measure of fiscal capacity is not equivalent to an estimated procyclicality coefficient, so the thesis must settle this definition before processing. |
| `FIN` | Refreshed raw input available | `data/raw/world_bank_wdi/`, `data/raw/fin/world_bank_wdi/` | `data/processed/fin/` | Domestic credit to the private sector covers 1,244 of 1,485 country-years (83.8%), with observations for 54 of the 55 countries. |
| Master panel | Draft available | Multiple raw folders | `data/processed/00_master_panel/` | Integrated country-year files generated by `scripts/panel/build_master_panel.py`. |

## Shared Atlas trade source

`data/raw/atlas/sitc_rev2_trade/` is the common raw source for DRES, HHI,
DIVX, PEXP and FEXP. The 233 country files are kept only once under
`country_exports/`; variable-specific raw folders must not contain copies of
the same Atlas data. Each variable reads this shared source and writes only its
derived results to the corresponding folder under `data/processed/`.

## Shared World Bank WDI source

`data/raw/world_bank_wdi/` contains the 17 WDI indicators required for the
current model or for narrowly defined validation exercises. The original ZIP
for each indicator is retained once under `source_zips/`, while
`wdi_thesis_inputs_1980_2022.csv` provides a single country-year table for
subsequent processing. This shared source prevents repeated copies of
population, GDP and other inputs across variable-specific raw folders.

## Shared Penn World Table source

`data/raw/pwt/pwt110.dta` stores PWT 11.0 only once because the same official
file supplies the human-capital index `hc` and the price-level measure
`pl_gdpo`. Variable-specific scripts extract only their required columns; they
must not create additional copies of the complete PWT source file.
