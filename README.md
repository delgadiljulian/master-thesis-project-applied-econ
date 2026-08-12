# Extractive Rents and External Structural Transformation

Reproducible research repository for the **Master's Thesis** in the
**Master's Program in Applied Economics** at the University of Buenos Aires.

**Author:** Julian Delgadillo Marin

**Advisor:** Martin Grandes

**Institution:** University of Buenos Aires, Faculty of Economic Sciences

**Reference version:** Manuscript prepared for advisor review, August 2026

---

## Overview

This repository organizes the documentary, empirical, and reproducible research
infrastructure for a thesis on natural resource dependence, extractive rents, and
structural transformation.

The project starts from a central tension in development economics: natural
resources can support productive capability accumulation, technological learning,
and long-run growth, but they can also reproduce trajectories of extractive
specialization, low economic complexity, macroeconomic volatility, and
institutional weakness.

The thesis does not ask whether natural resources are inherently a "blessing" or
a "curse". Instead, it analyzes the conditions under which economies dependent on
non-renewable natural resources are able to translate extractive rents into more
favorable trajectories of external structural transformation.

The current empirical design distinguishes between:

- **External natural resource dependence (`DRES`)**: used as a sample selection
  criterion based on the share of non-renewable subsoil-resource exports in
  merchandise exports.
- **Extractive rents (`RENTS`)**: treated as an explanatory mechanism, measured as
  the sum of oil, natural-gas, coal and mineral rents as a share of GDP.
- **Economic complexity (`ECI`)**: the main dependent variable, used as a measure
  of export sophistication and revealed productive capabilities.
- **Export diversification (`DIVX = 1 - HHI`)**: complementary dependent variable,
  used to evaluate whether the mechanisms associated with complexity are also
  related to a less concentrated export basket.

This separation is important: the sample is defined by external dependence on
resources, while the econometric model explains differences in complexity and
diversification through extractive rents and other productive, institutional,
macroeconomic, financial, and capability-related channels.

---

## Research Question

The research question is:

> How are extractive rents and productive, institutional, and macroeconomic
> channels associated with the external structural transformation of
> resource-dependent economies?

External structural transformation is observed primarily through `ECI`, as a
proxy for export sophistication and revealed productive capabilities, and
complementarily through `DIVX = 1 - HHI`, as a measure of export diversification.

---

## Contribution

The contribution of the thesis is not to propose a completely new theory of
natural resources and development, nor to claim that each variable is new in the
literature. Its value added lies in reorganizing the empirical problem in a clear
comparative framework:

- It separates the sample selection criterion (`DRES`) from the explanatory
  mechanism (`RENTS`).
- It studies external structural transformation using `ECI` as the main outcome
  and `DIVX = 1 - HHI` as a complementary outcome.
- It evaluates several channels jointly: institutional quality, resource
  abundance, export structure, macroeconomic conditions, productive capabilities,
  government consumption, and financial depth.
- It compares 55 economies dependent on oil, gas, and mining in a panel setting,
  selected with the single resource-dependence rule `theta = 20%`.

The thesis is therefore best understood as a comprehensive master's-level
empirical contribution: it does not claim causal closure, but it provides
organized comparative evidence on the conditions under which extractive rents are
associated with higher or lower levels of external structural transformation.

---

## General Objective

To comparatively analyze how productive, institutional, and macroeconomic
mechanisms are associated with differences in external structural transformation
and productive capability accumulation among resource-dependent economies during
  the main estimation period 1996-2021, using quantitative empirical evidence.

---

## Specific Objectives

- Identify and empirically evaluate productive mechanisms associated with
  extractive persistence, particularly Dutch disease, enclave formation, and weak
  productive linkages.
- Estimate the role of institutional quality and extractive rent governance in
  external structural transformation and productive capability accumulation.
- Analyze the impact of commodity price volatility and intertemporal
  macroeconomic constraints on savings, investment, and productive capability
  accumulation.
- Evaluate the extent to which human capital, innovation, and connectivity are
  associated with productive upgrading and external structural transformation.
- Compare external structural transformation trajectories across
  resource-dependent economies and identify differentiated patterns by dominant
  resource type.

---

## Methodology

The study follows a **quantitative**, **explanatory**, **non-experimental**, and
**longitudinal** research design.

The unit of analysis is the **country-year**. The main estimation period is
**1996-2021**, because the four WDI rent components required for `RENTS` end in
2021. Some raw sources cover a broader horizon through 2022 or 2023. The base
period **1990-1995** is used to classify external resource dependence through
`DRES`.

The methodological strategy combines:

- descriptive and exploratory analysis of the final panel;
- a hierarchical TWFE strategy with country and year fixed effects for `ECI`
  and `DIVX`;
- thematic specifications `M1` and `M2`, followed by the complete specification
  `M3` used as the main model;
- an interaction between extractive rents and institutional quality;
- country-clustered inference, wild cluster bootstrap, leave-one-country-out
  stability, a 2014 temporal sensitivity, country-specific linear trends, and
  a complementary disaggregation of extractive rents.

The fixed analytical grid contains 1,430 country-years for 55 economies. The
common complete-case estimation sample used by the central TWFE models contains
1,044 country-years from 49 countries and 23 effective years.

Given the observational nature of the design, results are interpreted as
conditional associations rather than strict causal estimates.

---

## Variables and Indicators

| Dimension | Indicator | Role | Source |
| --- | --- | --- | --- |
| External resource dependence | `DRES`: non-renewable subsoil-resource exports / merchandise exports | Sample selection criterion | Atlas of Economic Complexity, own construction |
| Extractive rents | `RENTS`: oil, natural-gas, coal and mineral rents as % of GDP | Explanatory variable | World Development Indicators |
| External structural transformation | `ECI`: Economic Complexity Index, HS92 | Main dependent variable | Atlas of Economic Complexity, official GraphQL API |
| Export diversification | `DIVX = 1 - HHI` | Complementary dependent variable | Own construction based on HHI |
| Export concentration | `HHI`: Herfindahl-Hirschman Index | Structural regressor in ECI models | Own construction from Atlas of Economic Complexity trade data |
| Resource abundance | `OILPC`, `GASPC`, `COALPC` | Abundance channel | World Development Indicators |
| Export specialization | `PEXP`, `FEXP` | Structural channel | Atlas of Economic Complexity |
| Institutions | `INST`: Control of Corruption, Rule of Law, Government Effectiveness | Institutional channel | Worldwide Governance Indicators |
| Human capital | `HUMCAP`: schooling-based human-capital index | Capability channel | UNDP Human Development Report 2025, own construction using PWT returns |
| Innovation | `INNOV`: log of scientific and technical articles per million inhabitants | Capability channel | World Development Indicators |
| Connectivity | `NET`: internet users as % of population | Capability channel | World Development Indicators |
| External volatility | `VOL`: five-year rolling volatility of the fixed-weight IMF commodity net-export price index | Macroeconomic channel | IMF CTOT |
| Real exchange rate | `RER`: `log(pl_gdpo)` | Macroeconomic channel | Penn World Table 11.0 |
| Government consumption | `GOVCONS`: government final consumption expenditure as % of GDP | Fiscal control | UN National Accounts Main Aggregates; WDI retained as reference |
| Financial depth | `FIN`: domestic credit to private sector by banks as % of GDP | Financial control | World Development Indicators |
| Development level | `log(GDPPC)`: GDP per capita, PPP, log | Control | World Development Indicators |

---

## Current Data and Econometric Status

- `DRES` is constructed and validated for 1990-1995. The single 20% rule
  selects 55 countries for both econometric specifications.
- `ECI`, `HHI`, and `DIVX` have reproducible processed country-year panels;
  ECI covers all 55 countries and 1,430 country-years in 1996-2021.
- The shared Atlas trade source is stored once and supplies `DRES`, `HHI`,
  `DIVX`, `PEXP`, and `FEXP`.
- The shared WDI download contains 11 indicators needed for the remaining
  variables. Forest rents and total natural-resource rents are excluded.
- `INNOV` raw inputs use scientific and technical articles and population; the
  55-country grid is complete for 1996-2022.
- `RER` raw inputs use only PWT 11.0 `pl_gdpo`, covering 52 of the 55 countries
  completely.
- `HUMCAP` uses UNDP mean years of schooling for adults aged 25 and older and
  applies the piecewise returns-to-education function used by PWT. It covers
  1,403 country-years (98.11%); PWT 11.0 `hc` remains only as a comparison
  series and is not mixed into the active indicator.
- `GOVCONS` uses UN National Accounts Main Aggregates series 16, item 3. The
  active panel covers all 1,430 country-years in 1996-2021; WDI remains
  unchanged as a comparison source and is not mixed into the active series.
- `FIN` uses the WDI bank-credit indicator `FD.AST.PRVT.GD.ZS`. It covers
  1,328 country-years (92.87%); the broader `FS.AST.PRVT.GD.ZS` series remains
  unchanged only as a comparison source and is not mixed into `FIN`.
- The master panel is complete and validated in equivalent CSV and Stata
  formats. The intersection required by the main specifications contains 1,044
  country-years from 49 countries.
- The authoritative econometric implementation is `stata-peer-2/01_twfe_main`.
  It contains the hierarchical `M1`-`M3` TWFE models, diagnostics, inference,
  stability checks, marginal effects, and extractive-rent disaggregation.
- The results, robustness exercises, discussion, conclusions, and supporting
  appendices are integrated into the current thesis manuscript.

Detailed variable definitions and coverage are documented in
[`data/DATA_INVENTORY.md`](data/DATA_INVENTORY.md).

---

## Thesis Structure

The master document is located at:

```text
docs/thesis/TFM.tex
```

The thesis source is organized through modular `subfiles`:

```text
docs/thesis/chapters/
  01-06-introduction-and-research-design/
  07-theoretical-framework/
  08-empirical-literature/
  09-methodology/
  10-data-and-variables/
  11-results/
  12-conclusions/
  13-cronograma/
  appendices/
  bibliography/
```

Shared figures are stored in:

```text
docs/thesis/figures/
```

---

## Repository Structure

```text
data/
  raw/                       # Raw data or placeholders
    atlas/                   # Shared Atlas source data
      sitc_rev2_trade/       # Country-year-product exports for several variables
    pwt/                     # Shared Penn World Table source for RER and HUMCAP contrast
    world_bank_wdi/          # Shared WDI source for several variables
    dres/                     # Inputs for DRES and sample filters
    eci/                     # Economic Complexity Index inputs
    rents/                   # Natural resource rents inputs
    inst/                    # Institutional quality inputs
    oilpc_gaspc_coalpc/      # Resource abundance inputs
    hhi_divx/                # Export concentration/diversification inputs
    pexp_fexp/               # Primary and fuel export share inputs
    vol/                     # Commodity volatility inputs
    rer/                     # Real exchange rate inputs
    humcap/                  # Human capital inputs
    innov/                   # Innovation inputs
    net/                     # Connectivity inputs
    gdppc/                   # GDP per capita inputs
    govcons/                 # Government consumption inputs
    fin/                     # Financial-depth inputs
  DATA_INVENTORY.md          # Variable checklist and source folders
  processed/                 # Processed data and harmonized outputs
    00_master_panel/         # Integrated country-year panels
    dres/                    # Sample-selection and dependence outputs
    eci/                     # Economic Complexity Index outputs
    rents/                   # Natural resource rents outputs
    inst/                    # Institutional quality outputs
    oilpc_gaspc_coalpc/      # Resource abundance outputs
    hhi_divx/                # Export concentration/diversification outputs
    pexp_fexp/               # Primary and fuel export share outputs
    vol/                     # Commodity volatility outputs
    rer/                     # Real exchange rate outputs
    humcap/                  # Human capital outputs
    innov/                   # Innovation outputs
    net/                     # Connectivity outputs
    gdppc/                   # GDP per capita outputs
    govcons/                 # Government consumption outputs
    fin/                     # Financial-depth outputs

docs/
  drafts/                    # Draft materials
  literature/                # Bibliography, notes, and literature material
  proposal/                  # Proposal-stage documents
  thesis/                    # Master thesis source, figures, and chapters

outputs/                     # Generated empirical or document outputs

scripts/
  data/                      # Data acquisition and preparation by variable
    atlas/                   # Shared Atlas trade-data acquisition
    pwt/                     # Shared Penn World Table acquisition
    world_bank_wdi/          # Shared WDI acquisition
    dres/                    # Sample-selection and dependence scripts
    eci/                     # Economic complexity scripts
    rents/                   # Natural resource rents scripts
    inst/                    # Institutional quality scripts
    oilpc_gaspc_coalpc/      # Resource abundance scripts
    hhi_divx/                # Export concentration/diversification scripts
    pexp_fexp/               # Primary and fuel export share scripts
    vol/                     # Commodity volatility scripts
    rer/                     # Real exchange rate scripts
    humcap/                  # Human capital scripts
    innov/                   # Innovation scripts
    net/                     # Connectivity scripts
    gdppc/                   # GDP per capita scripts
    govcons/                 # Government consumption scripts
    fin/                     # Financial-depth scripts
  panel/                     # Integrated country-year panel builders
  literature/                # Reproduction and extraction from prior studies
    anne2021/                # Anne (2021) commodity-specialization extraction
  econometrics/              # Stata TWFE estimation, inference, and sensitivities
    stata-peer-1/            # Independent comparison implementation
    stata-peer-2/            # Authoritative implementation for the thesis
  project_paths.R            # Shared R helper for project-relative paths
```

---

## Project Status

The substantive research cycle is complete:

- the raw and processed data architecture is documented and reproducible;
- the 55-country, 1996-2021 master panel is complete and validated;
- the main `ECI` and complementary `DIVX` TWFE models are estimated;
- diagnostics, bootstrap inference, stability checks, temporal sensitivity,
  country trends, marginal effects, and resource disaggregation are available;
- the methodology, data, results, conclusions, bibliography, and appendices are
  integrated into the thesis manuscript.

The project is now in the advisor-review and final-editing stage. Remaining work
is limited to incorporating advisor feedback, completing the abstract, keywords,
and acknowledgements, resolving minor bibliographic details, and preparing the
final institutional submission.

---

## Reproducibility Principles

This repository is designed as a structured and replicable research environment.
Its organization aims to ensure:

- separation between raw and processed data;
- script-based variable construction;
- explicit operational definitions;
- traceability of transformations and methodological decisions;
- reproduction of figures, tables, and models;
- sufficient documentation for academic review and future extensions.

---

## License

MIT License. Open for academic and research use.
