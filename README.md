# Natural Resource Dependence and Structural Transformation

Reproducible research repository for the **Master's Thesis Project** in the
**Master's Program in Applied Economics** at the University of Buenos Aires.

**Author:** Julian Delgadillo Marin

**Advisor:** Martin Grandes

**Institution:** University of Buenos Aires, Faculty of Economic Sciences

**Reference version:** Master's thesis project, 2026

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
  criterion based on the share of non-renewable resource exports in total exports.
- **Extractive rents (`RENTS`)**: treated as an explanatory mechanism, measured as
  natural resource rents as a share of GDP.
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

The general research question is:

> Why are some resource-dependent economies able to translate extractive rents
> into more favorable structural transformation trajectories, while others remain
> trapped in patterns of extractive specialization?

The specific empirical question is:

> How do productive, institutional, and macroeconomic factors interact to explain
> differences in external structural transformation trajectories among economies
> dependent on natural resources during the main estimation period 1996-2022,
> considering a broader data collection horizon for selected variables?

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
  fiscal constraints, and financial development.
- It compares economies dependent on oil, gas, and mining in a panel setting,
  using `theta = 40%` as the reference resource-dependence threshold and
  `theta = 50%` and `theta = 60%` as stricter sensitivity checks.

The thesis is therefore best understood as a comprehensive master's-level
empirical contribution: it does not claim causal closure, but it provides
organized comparative evidence on the conditions under which extractive rents are
associated with higher or lower levels of external structural transformation.

---

## General Objective

To comparatively analyze how productive, institutional, and macroeconomic
mechanisms are associated with differences in external structural transformation
and productive capability accumulation among resource-dependent economies during
the main estimation period 1996-2022, using quantitative empirical evidence.

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
**1996-2022**, while some data sources cover a broader horizon depending on
availability. The base period **1990-1995** is used to classify external resource
dependence through `DRES`.

The methodological strategy combines:

- descriptive and exploratory analysis of the final panel;
- panel data models with country and time effects;
- interactions between extractive rents and institutional quality;
- complementary estimations using `DIVX = 1 - HHI`;
- sensitivity checks using the `DRES` thresholds `40%`, `50%`, and `60%`;
- heterogeneity analysis by dominant resource type;
- additional robustness checks, including alternative specifications when
  justified by the data.

Given the observational nature of the design, results are interpreted as
conditional associations rather than strict causal estimates.

---

## Variables and Indicators

| Dimension | Indicator | Role | Source |
| --- | --- | --- | --- |
| External resource dependence | `DRES`: non-renewable resource exports / total exports | Sample selection criterion | UN Comtrade, World Bank, own construction |
| Extractive rents | `RENTS`: natural resource rents as % of GDP | Explanatory variable | World Development Indicators |
| External structural transformation | `ECI`: Economic Complexity Index, HS92 | Main dependent variable | Atlas of Economic Complexity |
| Export diversification | `DIVX = 1 - HHI` | Complementary dependent variable | Own construction based on HHI |
| Export concentration | `HHI`: Herfindahl-Hirschman Index | Structural regressor in ECI models | UN Comtrade, Atlas of Economic Complexity |
| Resource abundance | `OILPC`, `GASPC`, `COALPC` | Abundance channel | International energy and resource data |
| Export specialization | `PEXP`, `FEXP` | Structural channel | UN Comtrade, World Bank |
| Institutions | `INST`: Rule of Law, Control of Corruption | Institutional channel | Worldwide Governance Indicators |
| Human capital | `HUMCAP`: average years of schooling | Capability channel | Barro-Lee, World Bank |
| Innovation | `INNOV`: R&D expenditure or patents | Capability channel | UNESCO, WIPO |
| Connectivity | `NET`: internet access/use or digital infrastructure | Capability channel | World Bank, ITU |
| External volatility | `VOL`: commodity price volatility | Macroeconomic channel | World Bank Pink Sheet |
| Real exchange rate | `RER`: real effective exchange rate | Macroeconomic channel | World Bank, BIS, IMF |
| Fiscal channel | `FISC`: fiscal balance or public debt | Fiscal channel | IMF, World Bank |
| Financial development | `FIN`: domestic credit to private sector | Financial channel | World Development Indicators |
| Development level | `log(GDPPC)`: GDP per capita, PPP, log | Control | World Development Indicators |

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
    00_sample_selection_dres/ # Inputs for DRES and sample filters
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
    fisc/                    # Fiscal channel inputs
    fin/                     # Financial development inputs
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
    fisc/                    # Fiscal channel outputs
    fin/                     # Financial development outputs

docs/
  drafts/                    # Draft materials
  literature/                # Bibliography, notes, and literature material
  proposal/                  # Proposal-stage documents
  thesis/                    # Master thesis source, figures, and chapters

outputs/                     # Generated empirical or document outputs

scripts/
  00_master_panel/           # Integrated panel builders
  dres/                      # Sample-selection and dependence scripts
  eci/                       # Economic complexity scripts
  rents/                     # Natural resource rents scripts
  inst/                      # Institutional quality scripts
  oilpc_gaspc_coalpc/        # Resource abundance scripts
  hhi_divx/                  # Export concentration/diversification scripts
  pexp_fexp/                 # Primary and fuel export share scripts
  vol/                       # Commodity volatility scripts
  rer/                       # Real exchange rate scripts
  humcap/                    # Human capital scripts
  innov/                     # Innovation scripts
  net/                       # Connectivity scripts
  gdppc/                     # GDP per capita scripts
  fisc/                      # Fiscal channel scripts
  fin/                       # Financial development scripts
```

---

## Project Status

Advanced components:

- Introduction, research question, justification, and problem statement.
- Objectives, hypotheses, and contribution section.
- Theoretical framework.
- Empirical literature review.
- Methodological design.
- Operational definition of variables.
- Initial data and reproducibility architecture.
- Placeholder structure for the results chapter.

Components under development:

- Final empirical panel construction.
- Econometric estimation.
- Robustness and sensitivity analysis.
- Results discussion.
- Final conclusions.

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
