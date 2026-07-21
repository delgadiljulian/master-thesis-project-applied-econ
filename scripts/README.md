# Scripts

Scripts are organized first by research stage and then, within the data stage,
by thesis variable or by shared source when one download supports several
variables.

```text
scripts/
  data/                       # Acquisition and preparation of thesis data
    atlas/                    # Shared Atlas SITC trade-data acquisition
    pwt/                      # Shared Penn World Table acquisition
    world_bank_wdi/           # Shared WDI acquisition for several variables
    dres/                     # Sample selection and resource dependence
    eci/                      # Economic Complexity Index
    rents/                    # Natural resource rents
    inst/                     # Institutional quality
    oilpc_gaspc_coalpc/       # Resource abundance
    hhi_divx/                 # Export concentration and diversification
    pexp_fexp/                # Primary and fuel export shares
    vol/                      # Commodity volatility
    rer/                      # Real exchange rate
    humcap/                   # Human capital
    innov/                    # Innovation
    net/                      # Digital connectivity
    gdppc/                    # GDP per capita
    fisc/                     # Fiscal channel
    fin/                      # Financial development
  panel/                      # Integration of the country-year master panel
  literature/                 # Reproduction and extraction from prior studies
    anne2021/                 # Commodity-specialization tables from Anne (2021)
  econometrics/               # Future thesis estimations and diagnostics
  project_paths.R             # Shared project-path helper for R scripts
```

## Workflow

1. `data/` downloads, imports, cleans, and prepares the inputs required for each
   variable. These scripts write to the corresponding folders under
   `data/raw/` or `data/processed/`.
   Every official processed panel is saved with identical content and structure
   in CSV (`.csv`) and Stata (`.dta`) formats.
2. `panel/` combines the prepared variables into the country-year datasets under
   `data/processed/00_master_panel/`.
3. `literature/` contains scripts that reproduce or extract evidence from prior
   studies. These are supporting inputs, not thesis-variable constructors.
4. `econometrics/` will contain the descriptive analysis, panel models,
   interactions, heterogeneity exercises, and robustness checks. Its generated
   tables and figures should be written under `outputs/`.

Script filenames do not use numeric prefixes. The stage is identified by the
folder where each script lives.

## Implemented data workflow

The current reproducible sequence is:

1. `data/atlas/atlas_sitc_trade_data.R` downloads the shared SITC Rev. 2 trade
   source.
2. `data/dres/dres_sample_selection.R` constructs DRES and the nested 20%, 30%,
   and 40% samples; `dres_robustness_audit.R` checks the product scope and sample
   sensitivity.
3. `data/eci/eci_atlas_data.R` and `data/hhi_divx/hhi_divx_atlas.R` construct
   the processed ECI, HHI, and DIVX panels.
4. `data/world_bank_wdi/wdi_thesis_inputs.R` downloads the shared WDI inputs.
5. `data/pwt/pwt11_data.R` downloads the shared PWT 11.0 source.
6. `data/innov/innov_wdi_data.R` and `data/rer/rer_pwt_wdi_data.R` prepare the
   raw inputs and coverage diagnostics for INNOV and RER.

Scripts can be executed from the repository root or from RStudio because
`project_paths.R` locates the project without relying on a fixed working
directory.

## Commenting convention

Every script, whether written in R, Python, or another language, must be
readable by a thesis examiner without prior experience in that language. Use
clear Spanish comments following these rules:

- begin with a short description of the script's purpose, inputs, and outputs;
- add a brief comment before each instruction or logical line explaining what
  it does, what information it uses, or why it is necessary;
- explain data filters, transformations, joins, formulas, and methodological
  decisions in plain language;
- document function parameters and returned objects;
- identify validation checks and the reason execution would stop;
- state which files are created or modified and where they are stored;
- use short inline comments for function arguments when they improve clarity.

Closing parentheses and braces do not require comments because they only mark
the structure of the code. Comments should help a non-programmer follow the
research workflow without merely repeating the code mechanically.
