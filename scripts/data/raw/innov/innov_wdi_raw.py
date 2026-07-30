"""CAPA: RAW.
VARIABLE: INNOV.
ENTRADAS: panel WDI compartido y muestra DRES del 20 %.
SALIDAS: data/raw/innov/.

# Ejecutar la siguiente instrucción del bloque
Prepara los únicos insumos raw seleccionados para INNOV.

# Ejecutar la siguiente instrucción del bloque
La variable utiliza artículos científicos y técnicos por millón de habitantes.
En raw se conservan por separado el conteo de artículos y la población, sin
calcular tasas ni logaritmos.
"""

# Cargar librerías y módulos requeridos
from pathlib import Path

# Cargar librerías y módulos requeridos
import numpy as np
import pandas as pd


# Ejecutar la siguiente instrucción del bloque
PROJECT_PATH = Path(__file__).resolve().parents[4]
WDI_SOURCE = (
    PROJECT_PATH
    / "data"
    / "raw"
    / "world_bank_wdi"
    / "wdi_thesis_inputs_1980_2022.csv"
)
DRES_SAMPLE = (
    PROJECT_PATH
    / "data"
    / "processed"
    / "dres"
    / "dres_sample_20.csv"
)
OUTPUT_PATH = (
    PROJECT_PATH / "data" / "raw" / "innov" / "world_bank_wdi"
)
ANALYSIS_YEARS = list(range(1996, 2023))


# Definir función principal o auxiliar
def main() -> None:
    """Extrae los insumos WDI, valida cobertura y escribe las salidas raw."""

    # Iterar sobre los elementos del conjunto
    for path in [WDI_SOURCE, DRES_SAMPLE]:
        if not path.is_file():
            raise FileNotFoundError(f"Falta el insumo requerido: {path}")

    # Cargar el archivo de datos
    sample = pd.read_csv(DRES_SAMPLE, dtype={"country_iso3_code": "string"})
    sample["country_iso3_code"] = (
        sample["country_iso3_code"].str.strip().str.upper()
    )
    if len(sample) != 55 or sample["country_iso3_code"].duplicated().any():
        raise ValueError("La muestra DRES no contiene 55 paises unicos.")

    # Cargar el archivo de datos
    wdi = pd.read_csv(
        WDI_SOURCE,
        dtype={"country_iso3_code": "string"},
    )
    required = [
        "country_iso3_code",
        "country",
        "year",
        "scientific_technical_journal_articles",
        "population_total",
    ]
    missing = sorted(set(required) - set(wdi.columns))
    if missing:
        raise ValueError("Faltan columnas WDI: " + ", ".join(missing))

    # Ejecutar la siguiente instrucción del bloque
    innov_raw = wdi[required].rename(
        columns={
            "scientific_technical_journal_articles": "scientific_articles"
        }
    )
    innov_raw["country_iso3_code"] = (
        innov_raw["country_iso3_code"].str.strip().str.upper()
    )
    innov_raw["country"] = innov_raw["country"].astype("string")
    innov_raw["year"] = innov_raw["year"].astype("int64")
    innov_raw["scientific_articles"] = pd.to_numeric(
        innov_raw["scientific_articles"], errors="coerce"
    ).astype("float64")
    innov_raw["population_total"] = pd.to_numeric(
        innov_raw["population_total"], errors="coerce"
    ).astype("float64")
    innov_raw = innov_raw.sort_values(
        ["country_iso3_code", "year"]
    ).reset_index(drop=True)

    # Evaluar condición de control de flujo
    if innov_raw.duplicated(["country_iso3_code", "year"]).any():
        raise ValueError("INNOV contiene llaves pais-anio duplicadas.")
    if not innov_raw["country_iso3_code"].str.fullmatch(r"[A-Z]{3}").all():
        raise ValueError("INNOV contiene codigos ISO3 invalidos.")
    if not innov_raw["year"].between(1980, 2022).all():
        raise ValueError("INNOV contiene anios fuera de 1980-2022.")
    observed_articles = innov_raw["scientific_articles"].dropna()
    observed_population = innov_raw["population_total"].dropna()
    if (
        not np.isfinite(observed_articles).all()
        or (observed_articles < 0).any()
    ):
        raise ValueError("Los articulos contienen valores invalidos.")
    if (
        not np.isfinite(observed_population).all()
        or (observed_population <= 0).any()
    ):
        raise ValueError("La poblacion contiene valores invalidos.")

    # Ejecutar la siguiente instrucción del bloque
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
        innov_raw[
            [
                "country_iso3_code",
                "year",
                "scientific_articles",
                "population_total",
            ]
        ],
        on=["country_iso3_code", "year"],
        how="left",
        validate="one_to_one",
    )
    if len(grid) != 1485:
        raise ValueError("La cuadricula DRES de INNOV no tiene 1.485 celdas.")

    # Ejecutar la siguiente instrucción del bloque
    grid["input_bundle_observed"] = (
        grid["scientific_articles"].notna()
        & grid["population_total"].notna()
    )
    coverage_rows: list[dict[str, object]] = []
    for country_code, country_data in grid.groupby(
        "country_iso3_code", sort=True
    ):
        observed = country_data["input_bundle_observed"]
        missing_years = country_data.loc[~observed, "year"]
        coverage_rows.append(
            {
                "country_iso3_code": country_code,
                "country": country_data["country"].iloc[0],
                "expected_years": len(ANALYSIS_YEARS),
                "observed_input_years": int(observed.sum()),
                "coverage_percent": 100 * observed.mean(),
                "missing_years": ";".join(
                    missing_years.astype(str).tolist()
                ),
                "complete_1996_2022": bool(observed.all()),
            }
        )

    # Ejecutar la siguiente instrucción del bloque
    country_coverage = pd.DataFrame(coverage_rows)
    observed_bundle = grid["input_bundle_observed"]
    coverage_summary = pd.DataFrame(
        [
            {
                "variable": "scientific_articles_and_population",
                "source_codes": "IP.JRN.ARTC.SC;SP.POP.TOTL",
                "expected_country_years_1996_2022": 1485,
                "observed_country_years_1996_2022": int(
                    observed_bundle.sum()
                ),
                "coverage_percent_1996_2022": 100 * observed_bundle.mean(),
                "countries_with_any_data": int(
                    (country_coverage["observed_input_years"] > 0).sum()
                ),
                "countries_complete_1996_2022": int(
                    country_coverage["complete_1996_2022"].sum()
                ),
                "countries_without_data": int(
                    (country_coverage["observed_input_years"] == 0).sum()
                ),
            }
        ]
    )

    # Ejecutar la siguiente instrucción del bloque
    OUTPUT_PATH.mkdir(parents=True, exist_ok=True)
    innov_raw.to_csv(
        OUTPUT_PATH / "innov_wdi_input_1980_2022.csv",
        index=False,
        na_rep="",
        encoding="utf-8",
    )
    innov_raw.to_stata(
        OUTPUT_PATH / "innov_wdi_input_1980_2022.dta",
        write_index=False,
        version=118,
    )
    coverage_summary.to_csv(
        OUTPUT_PATH / "innov_raw_coverage_summary_dres20.csv",
        index=False,
        na_rep="",
        encoding="utf-8",
    )
    country_coverage.to_csv(
        OUTPUT_PATH / "innov_raw_country_coverage_dres20.csv",
        index=False,
        na_rep="",
        encoding="utf-8",
    )

    # Ejecutar la siguiente instrucción del bloque
    print("Raw de INNOV terminado.")
    print(coverage_summary.to_string(index=False))


# Evaluar condición de control de flujo
if __name__ == "__main__":
    main()
