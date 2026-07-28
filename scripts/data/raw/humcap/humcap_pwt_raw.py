"""CAPA: RAW.

Prepara el unico insumo raw seleccionado para HUMCAP.

Fuente: indice de capital humano ``hc`` de Penn World Table 11.0.
El script conserva los niveles publicados y genera diagnosticos de cobertura;
no interpola, imputa ni transforma la serie.
"""

from pathlib import Path

import numpy as np
import pandas as pd


# Localizar la raiz del repositorio a partir de scripts/data/raw/humcap/.
PROJECT_PATH = Path(__file__).resolve().parents[4]

# Definir el archivo compartido, la muestra y la carpeta de salida.
PWT_SOURCE = PROJECT_PATH / "data" / "raw" / "pwt" / "pwt110.dta"
DRES_SAMPLE = (
    PROJECT_PATH
    / "data"
    / "processed"
    / "dres"
    / "dres_sample_20.csv"
)
OUTPUT_PATH = PROJECT_PATH / "data" / "raw" / "humcap" / "pwt"
ANALYSIS_YEARS = list(range(1996, 2023))


def require_files(paths: list[Path]) -> None:
    """Detiene la ejecucion si falta algun insumo requerido."""

    missing = [str(path) for path in paths if not path.is_file()]
    if missing:
        raise FileNotFoundError(
            "Faltan insumos requeridos:\n" + "\n".join(missing)
        )


def validate_raw(data: pd.DataFrame) -> None:
    """Valida llaves, codigos, horizonte y valores del extracto PWT."""

    if data.duplicated(["country_iso3_code", "year"]).any():
        raise ValueError("El extracto contiene llaves pais-anio duplicadas.")
    if not data["country_iso3_code"].str.fullmatch(r"[A-Z]{3}").all():
        raise ValueError("El extracto contiene codigos ISO3 invalidos.")
    if not data["year"].between(1950, 2023).all():
        raise ValueError("El extracto contiene anios fuera de 1950-2023.")

    observed = data["human_capital_index_pwt"].dropna()
    if not np.isfinite(observed).all() or (observed <= 0).any():
        raise ValueError("El indice hc contiene valores no positivos o no finitos.")


def build_coverage(
    data: pd.DataFrame,
    sample: pd.DataFrame,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Construye diagnosticos general y por pais para 1996-2022."""

    sample_codes = sample["country_iso3_code"].sort_values().tolist()
    grid = pd.MultiIndex.from_product(
        [sample_codes, ANALYSIS_YEARS],
        names=["country_iso3_code", "year"],
    ).to_frame(index=False)
    grid = grid.merge(
        sample[["country_iso3_code", "country"]],
        on="country_iso3_code",
        how="left",
        validate="many_to_one",
    )
    grid = grid.merge(
        data[
            ["country_iso3_code", "year", "human_capital_index_pwt"]
        ],
        on=["country_iso3_code", "year"],
        how="left",
        validate="one_to_one",
    )

    expected_cells = len(sample_codes) * len(ANALYSIS_YEARS)
    if len(grid) != expected_cells:
        raise ValueError("La cuadricula DRES no tiene 1.485 celdas.")

    coverage_rows: list[dict[str, object]] = []
    for country_code, country_data in grid.groupby(
        "country_iso3_code", sort=True
    ):
        observed = country_data["human_capital_index_pwt"].notna()
        observed_values = country_data.loc[
            observed, "human_capital_index_pwt"
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
    observed_grid = grid["human_capital_index_pwt"].notna()
    observed_values = grid.loc[
        observed_grid, "human_capital_index_pwt"
    ]
    summary = pd.DataFrame(
        [
            {
                "variable": "human_capital_index_pwt",
                "source_code": "PWT11.0:hc",
                "expected_country_years_1996_2022": expected_cells,
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
    return country_coverage, summary


def main() -> None:
    """Extrae PWT 11.0, valida la serie y escribe las salidas raw."""

    require_files([PWT_SOURCE, DRES_SAMPLE])
    OUTPUT_PATH.mkdir(parents=True, exist_ok=True)

    # Leer y validar la muestra fija de 55 paises.
    sample = pd.read_csv(DRES_SAMPLE, dtype={"country_iso3_code": "string"})
    sample["country_iso3_code"] = (
        sample["country_iso3_code"].str.strip().str.upper()
    )
    if len(sample) != 55 or sample["country_iso3_code"].duplicated().any():
        raise ValueError("La muestra DRES no contiene 55 paises unicos.")

    # Extraer exclusivamente el indice hc desde PWT 11.0.
    pwt_source = pd.read_stata(PWT_SOURCE, convert_categoricals=False)
    required = ["countrycode", "country", "year", "hc"]
    missing = sorted(set(required) - set(pwt_source.columns))
    if missing:
        raise ValueError("Faltan columnas PWT: " + ", ".join(missing))

    humcap_raw = pwt_source[required].rename(
        columns={
            "countrycode": "country_iso3_code",
            "hc": "human_capital_index_pwt",
        }
    )
    humcap_raw["country_iso3_code"] = (
        humcap_raw["country_iso3_code"]
        .astype("string")
        .str.strip()
        .str.upper()
    )
    humcap_raw["country"] = humcap_raw["country"].astype("string")
    humcap_raw["year"] = humcap_raw["year"].astype("int64")
    humcap_raw["human_capital_index_pwt"] = pd.to_numeric(
        humcap_raw["human_capital_index_pwt"], errors="coerce"
    ).astype("float64")
    humcap_raw = humcap_raw.sort_values(
        ["country_iso3_code", "year"]
    ).reset_index(drop=True)
    validate_raw(humcap_raw)

    # Construir los diagnosticos para el periodo de estimacion.
    country_coverage, coverage_summary = build_coverage(
        humcap_raw, sample
    )

    # Guardar el extracto canonico en CSV y Stata.
    humcap_raw.to_csv(
        OUTPUT_PATH / "humcap_pwt11_input_1950_2023.csv",
        index=False,
        na_rep="",
        encoding="utf-8",
    )
    humcap_raw.to_stata(
        OUTPUT_PATH / "humcap_pwt11_input_1950_2023.dta",
        write_index=False,
        version=118,
    )

    # Mantener el alias utilizado por el constructor antiguo del panel.
    humcap_raw.rename(
        columns={"human_capital_index_pwt": "HUMCAP"}
    ).to_stata(
        OUTPUT_PATH / "humcap_pwt.dta",
        write_index=False,
        version=118,
    )

    # Guardar los diagnosticos de cobertura.
    coverage_summary.to_csv(
        OUTPUT_PATH / "humcap_pwt_raw_coverage_summary_dres20.csv",
        index=False,
        na_rep="",
        encoding="utf-8",
    )
    country_coverage.to_csv(
        OUTPUT_PATH / "humcap_pwt_raw_country_coverage_dres20.csv",
        index=False,
        na_rep="",
        encoding="utf-8",
    )

    print("Raw de HUMCAP terminado.")
    print(coverage_summary.to_string(index=False))


if __name__ == "__main__":
    main()
