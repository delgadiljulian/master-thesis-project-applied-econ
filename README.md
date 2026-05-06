# Natural Resource Dependence and Structural Transition Trajectories (1980-2022)

Reproducible research repository for the **Master's Thesis Project** in the
**Master's Program in Applied Economics** at the University of Buenos Aires.

**Author:** Julián Delgadillo Marín  
**Advisor:** Martín Grandes  
**Institution:** University of Buenos Aires, Faculty of Economic Sciences  
**Reference version:** Master's thesis project, February 2026

---

## Overview

This repository organizes the documentary, empirical, and reproducible research
infrastructure for a thesis on natural resource dependence, extractive rents, and
structural transformation.

The project starts from a central tension in development economics: natural resources can
serve as a platform for productive capability accumulation, technological learning, and
long-run growth, but they can also reproduce trajectories of extractive specialization,
low economic complexity, macroeconomic volatility, and institutional weakness.

The goal is not to determine whether natural resources are inherently a "blessing" or a
"curse". Instead, the thesis analyzes the conditions under which resource-dependent
economies are able to translate extractive rents into more favorable structural
transformation trajectories.

The thesis distinguishes between:

- **External natural resource dependence:** used as a sample selection criterion based on
  export structure.
- **Macroeconomic intensity of extractive rents:** treated as an explanatory mechanism in
  the empirical analysis.
- **External structural transformation:** sophistication and diversification of the export
  basket, proxied by the Economic Complexity Index (ECI).
- **Internal structural transformation:** changes in the domestic productive structure,
  proxied by manufacturing and services value added.

---

## Research Question

The general research question is:

> Why are some resource-dependent economies able to translate extractive rents into more
> favorable structural transformation trajectories, while others remain trapped in
> patterns of extractive specialization?

The specific empirical question is:

> How do productive, institutional, and macroeconomic factors interact to explain
> differences in structural transformation trajectories, both external and internal,
> among resource-dependent economies during 1980-2022?

---

## General Objective

To comparatively analyze how productive, institutional, and macroeconomic mechanisms are
associated with differences in structural transformation trajectories, both external and
internal, and in productive capability accumulation among resource-dependent economies
during 1980-2022, using quantitative empirical evidence.

---

## Specific Objectives

- Identify and empirically evaluate productive mechanisms associated with extractive
  persistence, particularly Dutch disease, enclave formation, and weak productive
  linkages.
- Estimate the role of institutional quality and extractive rent governance in structural
  transformation and productive capability accumulation trajectories.
- Analyze the impact of international commodity price volatility and intertemporal
  macroeconomic constraints on savings, investment, and productive capability
  accumulation.
- Evaluate the extent to which human capital and innovation are associated with
  productive upgrading and more favorable structural transformation trajectories.
- Compare structural transformation trajectories across resource-dependent economies and
  identify differentiated patterns of productive performance.
- Analyze systematic differences between hydrocarbon-dependent and mining-dependent
  economies.

---

## Hypotheses

The general hypothesis is that resource-dependent economies that successfully translate
extractive rents into more favorable structural transformation and productive capability
accumulation trajectories are characterized by denser productive linkages, more effective
institutional arrangements, and macroeconomic management capable of dampening volatility
associated with extractive commodity cycles.

The specific hypotheses organize five main mechanisms:

- Productive mechanisms of extractive persistence, such as Dutch disease, enclave
  structures, and weak linkages, are associated with worse structural transformation
  outcomes.
- Institutional quality and extractive rent governance moderate the effect of dependence
  on structural transformation and capability accumulation.
- Commodity price volatility and procyclical macroeconomic management reduce the
  probability that extractive rents are transformed into savings, investment, and
  sustained productive capabilities.
- Higher levels of human capital and innovation increase the probability of productive
  upgrading.
- The association between extractive dependence and structural transformation varies by
  dominant resource type: hydrocarbons or mining.

---

## Analytical Framework

The research brings together literature on:

- Natural resource curse and resource-based development.
- Dutch disease, real exchange rate dynamics, and manufacturing displacement.
- Extractive enclaves, productive linkages, and technological learning.
- Political economy of rents, institutional quality, and rent-seeking behavior.
- Commodity volatility, fiscal constraints, and macroeconomic management.
- Economic complexity, product space, and productive capability accumulation.
- External and internal structural transformation.

The approach avoids deterministic interpretations: resource dependence does not
automatically lead either to structural lock-in or to successful development. Its effects
depend on the interaction between productive capabilities, institutions, macroeconomic
conditions, and the type of extractive specialization.

---

## Methodology

The study follows a **quantitative**, **explanatory**, **non-experimental**, and
**longitudinal** research design.

The unit of analysis is the **country-year**. The empirical base is organized as an
international panel for **1980-2022**, potentially unbalanced depending on data
availability.

The methodological strategy combines:

- Comparative descriptive analysis.
- Panel data models.
- Dynamic specifications.
- Interactions between extractive rents and institutions.
- Heterogeneity analysis by resource type and income group.
- Robustness checks using alternative indicators of structural transformation.

Given the observational nature of the design, results are interpreted as robust
conditional associations rather than strict causal estimates.

---

## Variables and Indicators

| Dimension | Indicator | Source |
| --- | --- | --- |
| Extractive dependence | Resource exports / total exports | UN Comtrade, World Bank |
| Extractive rents | Natural resource rents as % of GDP | World Development Indicators |
| External transformation | Economic Complexity Index, HS92 | Atlas of Economic Complexity |
| Internal transformation | Manufacturing and services value added | World Bank, UN data |
| Export concentration | Herfindahl-Hirschman Index | UN Comtrade, Atlas of Economic Complexity |
| Institutions | Rule of Law, Control of Corruption | Worldwide Governance Indicators |
| Human capital | Average years of schooling | Barro-Lee, World Bank |
| Innovation | R&D expenditure or patents | UNESCO, WIPO |
| External volatility | Commodity price volatility | World Bank Pink Sheet |
| Real exchange rate | Real effective exchange rate | World Bank, BIS, IMF |
| Financial development | Domestic credit to private sector | World Development Indicators |
| Fiscal channel | Fiscal balance or public debt | IMF, World Bank |
| Development level | GDP per capita, PPP, log | World Development Indicators |

---

## Repository Structure

```text
data/
  raw/                       # Raw data or placeholders
  processed/                 # Processed data

docs/
  drafts/                    # Chapter drafts
  literature/                # Bibliography, maps, and literature synthesis
  methodology/               # Models, variables, identification, and robustness
  theory/                    # Conceptual framework and theoretical notes

governance/
  data_policy.md             # Data policy
  ethics_statement.md        # Ethics statement
  research_protocol.md       # Research protocol
  versioning_strategy.md     # Versioning strategy

reproducibility/
  environment.yml            # Conda environment
  requirements.txt           # Python dependencies
  dockerfile                 # Reproducible container environment
  run_pipeline.sh            # Pipeline entry point

scripts/
  01_eci_resource_dependence_figures.R

src/
  cleaning/                  # Cleaning and harmonization
  construction/              # Indicator construction
  diagnostics/               # Econometric diagnostics
  ingestion/                 # Data download and ingestion
  models/                    # Static, dynamic, and heterogeneity models
  visualization/             # Descriptive and results figures
```

---

## Project Status

Advanced components:

- Introduction, research question, justification, and problem statement.
- Objectives and hypotheses.
- Theoretical framework.
- Empirical literature review.
- Methodological design.
- Operational definition of variables.
- Initial data and reproducibility architecture.

Components under development:

- Final empirical panel construction.
- Econometric estimation.
- Robustness analysis.
- Results chapter.
- Discussion and final conclusions.

---

## Reproducibility Principles

This repository is designed as a structured and replicable research environment. Its
organization aims to ensure:

- Separation between raw and processed data.
- Script-based variable construction.
- Explicit operational definitions.
- Traceability of transformations and methodological decisions.
- Reproduction of figures, tables, and models.
- Sufficient documentation for academic audit and future extensions.

---

## License

MIT License. Open for academic and research use.
