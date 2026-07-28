"""CAPA: RAW.

Prepara el unico insumo raw seleccionado para RER.

Fuente: nivel de precios de la produccion ``pl_gdpo`` de PWT 11.0.
El logaritmo que define RER se aplicara posteriormente en data/processed.
"""

from pathlib import Path

import numpy as np
import pandas as pd


PROJECT_PATH = Path(__file__).resolve().parents[4]
PWT_SOURCE = PROJECT_PATH / "data" / "raw" / "pwt" / "pwt110.dta"
DRES_SAMPLE = (
    PROJECT_PATH
    / "data"
    / "processed"
    / "dres"
    / "dres_sample_20.csv"
)
OUTPUT_PATH = PROJECT_PATH / "data" / "raw" / "rer" / "pwt"
ANALYSIS_YEARS = list(range(1996, 2023))


def main() -> None:
    """Extrae pl_gdpo, valida la fuente y guarda diagnosticos raw."""

    for path in [PWT_SOURCE, DRES_SAMPLE]:
        if not path.is_file():
            raise FileNotFoundError(f"Falta el insumo requerido: {path}")

    sample = pd.read_csv(DRES_SAMPLE, dtype={"country_iso3_code": "string"})
    sample["country_iso3_code"] = (
        sample["country_iso3_code"].str.strip().str.upper()
    )
    if len(sample) != 55 or sample["country_iso3_code"].duplicated().any():
        raise ValueError("La muestra DRES no contiene 55 paises unicos.")

    pwt_source = pd.read_stata(PWT_SOURCE, convert_categoricals=False)
    required = ["countrycode", "country", "year", "pl_gdpo"]
    missing = sorted(set(required) - set(pwt_source.columns))
    if missing:
        raise ValueError("Faltan columnas PWT: " + ", ".join(missing))

    rer_raw = pwt_source[required].rename(
        columns={
            "countrycode": "country_iso3_code",
            "pl_gdpo": "output_price_level_pwt",
        }
    )
    rer_raw["country_iso3_code"] = (
        rer_raw["country_iso3_code"]
        .astype("string")
        .str.strip()
        .str.upper()
    )
    rer_raw["country"] = rer_raw["country"].astype("string")
    rer_raw["year"] = rer_raw["year"].astype("int64")
    rer_raw["output_price_level_pwt"] = pd.to_numeric(
        rer_raw["output_price_level_pwt"], errors="coerce"
    ).astype("float64")
    rer_raw = rer_raw.sort_values(
        ["country_iso3_code", "year"]
    ).reset_index(drop=True)

    if rer_raw.duplicated(["country_iso3_code", "year"]).any():
        raise ValueError("PWT contiene llaves pais-anio duplicadas para RER.")
    if not rer_raw["country_iso3_code"].str.fullmatch(r"[A-Z]{3}").all():
        raise ValueError("PWT contiene codigos ISO3 invalidos para RER.")
    if not rer_raw["year"].between(1950, 2023).all():
        raise ValueError("PWT contiene anios fuera de 1950-2023.")
    observed_source = rer_raw["output_price_level_pwt"].dropna()
    if (
        not np.isfinite(observed_source).all()
        or (observed_source <= 0).any()
    ):
        raise ValueError("pl_gdpo contiene valores no positivos o no finitos.")

    grid = pd.MultiIndex.from_product(
        [
            sample["country_iso3_code"].sort_values().tolist(),
            ANALYSIS_YEARS,
        ],
        names=["country_iso3_code", "year"],
    ).to_frame(index=False)
    grid = grid.merge(
        sample[["country_iso3_code", "country"]],
        on="country_iso3_code",
        how="left",
        validate="many_to_one",
    )
    grid = grid.merge(
        rer_raw[
            ["country_iso3_code", "year", "output_price_level_pwt"]
        ],
        on=["country_iso3_code", "year"],
        how="left",
        validate="one_to_one",
    )
    if len(grid) != 1485:
        raise ValueError("La cuadricula DRES de RER no tiene 1.485 celdas.")

    coverage_rows: list[dict[str, object]] = []
    for country_code, country_data in grid.groupby(
        "country_iso3_code", sort=True
    ):
        observed = country_data["output_price_level_pwt"].notna()
        observed_values = country_data.loc[
            observed, "output_price_level_pwt"
        ]
        observed_years = country_data.loc[observed, "year"]
        missing_years = country_data.loc[~observed, "year"]
        coverage_rows.append(
            {
                "country_iso3_code": country_code,
                "country": country_data["country"].iloc[0],
                "expected_years": len(ANALYSIS_YEARS),
                "observed_years": int(observed.sum()),
                "coverage_percent": 100 * observed.mean(),
                "first_observed_year": (
                    int(observed_years.min()) if observed.any() else np.nan
                ),
                "last_observed_year": (
                    int(observed_years.max()) if observed.any() else np.nan
                ),
                "minimum_observed_value": (
                    float(observed_values.min()) if observed.any() else np.nan
                ),
                "maximum_observed_value": (
                    float(observed_values.max()) if observed.any() else np.nan
                ),
                "missing_years": ";".join(
                    missing_years.astype(str).tolist()
                ),
                "complete_1996_2022": bool(observed.all()),
            }
        )

    country_coverage = pd.DataFrame(coverage_rows)
    observed_grid = grid["output_price_level_pwt"].notna()
    observed_values = grid.loc[observed_grid, "output_price_level_pwt"]
    coverage_summary = pd.DataFrame(
        [
            {
                "variable": "output_price_level_pwt",
                "source_code": "PWT11.0:pl_gdpo",
                "expected_country_years_1996_2022": 1485,
                "observed_country_years_1996_2022": int(
                    observed_grid.sum()
                ),
                "coverage_percent_1996_2022": 100 * observed_grid.mean(),
                "countries_with_any_data": int(
                    (country_coverage["observed_years"] > 0).sum()
                ),
                "countries_complete_1996_2022": int(
                    country_coverage["complete_1996_2022"].sum()
                ),
                "countries_incomplete_1996_2022": int(
                    (~country_coverage["complete_1996_2022"]).sum()
                ),
                "countries_without_data": int(
                    (country_coverage["observed_years"] == 0).sum()
                ),
                "first_observed_year": int(
                    grid.loc[observed_grid, "year"].min()
                ),
                "last_observed_year": int(
                    grid.loc[observed_grid, "year"].max()
                ),
                "minimum_observed_value": float(observed_values.min()),
                "median_observed_value": float(observed_values.median()),
                "maximum_observed_value": float(observed_values.max()),
            }
        ]
    )

    OUTPUT_PATH.mkdir(parents=True, exist_ok=True)
    rer_raw.to_csv(
        OUTPUT_PATH / "rer_pwt11_input_1950_2023.csv",
        index=False,
        na_rep="",
        encoding="utf-8",
    )
    rer_raw.to_stata(
        OUTPUT_PATH / "rer_pwt11_input_1950_2023.dta",
        write_index=False,
        version=118,
    )
    coverage_summary.to_csv(
        OUTPUT_PATH / "rer_pwt_raw_coverage_summary_dres20.csv",
        index=False,
        na_rep="",
        encoding="utf-8",
    )
    country_coverage.to_csv(
        OUTPUT_PATH / "rer_pwt_raw_country_coverage_dres20.csv",
        index=False,
        na_rep="",
        encoding="utf-8",
    )

    print("Raw de RER terminado.")
    print(coverage_summary.to_string(index=False))


if __name__ == "__main__":
    main()
