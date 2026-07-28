"""CAPA: RAW
VARIABLE: HUMCAP
ENTRADA: Human Development Report 2025, UNDP
SALIDAS: data/raw/humcap/undp_hdr/

Descarga la serie oficial de años medios de escolaridad del PNUD, conserva los
archivos fuente y prepara una cuadrícula larga para los 55 países DRES. Esta
capa no calcula el índice de capital humano ni completa valores faltantes.
"""

from __future__ import annotations

import csv
import hashlib
import io
import os
import tempfile
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import pandas as pd


DATA_URL = (
    "https://hdr.undp.org/sites/default/files/2025_HDR/"
    "HDR25_Composite_indices_complete_time_series.csv"
)
METADATA_URL = (
    "https://hdr.undp.org/sites/default/files/2025_HDR/"
    "HDR25_Composite_indices_metadata.xlsx"
)
SOURCE_VINTAGE = "Human Development Report 2025"
INDICATOR_CODE = "UNDP_HDR_MYS"
INDICATOR_NAME = "Mean Years of Schooling (years)"
START_YEAR = 1990
END_YEAR = 2023
ANALYSIS_START_YEAR = 1996
ANALYSIS_END_YEAR = 2021
EXPECTED_SAMPLE_COUNTRIES = 55
MINIMUM_ANALYSIS_OBSERVATIONS = 1390
MAX_ATTEMPTS = 3


def find_project_root() -> Path:
    """Localiza la raíz del repositorio desde la ubicación del script."""

    candidate = Path(__file__).resolve().parents[4]
    if not (candidate / "scripts" / "project_paths.R").exists():
        raise RuntimeError("No se pudo identificar la raíz del repositorio.")
    return candidate


def sha256(path: Path) -> str:
    """Calcula el hash SHA-256 de un archivo."""

    return hashlib.sha256(path.read_bytes()).hexdigest()


def atomic_write_bytes(path: Path, content: bytes) -> None:
    """Escribe bytes completos y reemplaza el destino al finalizar."""

    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f"{path.stem}_",
        suffix=".tmp",
        dir=path.parent,
    )
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(content)
        os.replace(temporary_name, path)
    except Exception:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)
        raise


def atomic_write_csv(
    path: Path,
    fieldnames: list[str],
    rows: list[dict[str, Any]],
) -> None:
    """Escribe un CSV completo y reemplaza el destino al finalizar."""

    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f"{path.stem}_",
        suffix=".tmp",
        dir=path.parent,
        text=True,
    )
    try:
        with os.fdopen(
            descriptor,
            "w",
            newline="",
            encoding="utf-8",
        ) as handle:
            writer = csv.DictWriter(handle, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(rows)
        os.replace(temporary_name, path)
    except Exception:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)
        raise


def download(url: str) -> bytes:
    """Descarga una fuente oficial con reintentos acotados."""

    request = urllib.request.Request(
        url,
        headers={"User-Agent": "master-thesis-data-pipeline/1.0"},
    )
    last_error: Exception | None = None
    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                content = response.read()
            if len(content) < 1000:
                raise RuntimeError(
                    f"La descarga desde {url} es anormalmente pequeña."
                )
            return content
        except (urllib.error.URLError, TimeoutError, RuntimeError) as error:
            last_error = error
            if attempt < MAX_ATTEMPTS:
                time.sleep(attempt)
    raise RuntimeError(f"No se pudo descargar {url}: {last_error}")


def read_sample(path: Path) -> dict[str, str]:
    """Lee y valida la muestra fija DRES."""

    with path.open("r", newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        required = {"country_iso3_code", "country"}
        if not required.issubset(reader.fieldnames or []):
            raise RuntimeError("La muestra DRES no tiene las columnas requeridas.")
        sample = {
            row["country_iso3_code"].strip().upper(): row["country"].strip()
            for row in reader
        }

    if (
        len(sample) != EXPECTED_SAMPLE_COUNTRIES
        or any(len(code) != 3 or not code.isalpha() for code in sample)
        or any(not country for country in sample.values())
    ):
        raise RuntimeError("La muestra DRES no contiene 55 países válidos.")
    return sample


def parse_source(
    content: bytes,
    sample: dict[str, str],
) -> tuple[list[dict[str, Any]], dict[str, str]]:
    """Extrae MYS para la muestra sin transformar ni imputar."""

    text = content.decode("latin-1")
    reader = csv.DictReader(io.StringIO(text))
    expected_columns = {
        "iso3",
        "country",
        *{f"mys_{year}" for year in range(START_YEAR, END_YEAR + 1)},
    }
    missing_columns = expected_columns.difference(reader.fieldnames or [])
    if missing_columns:
        raise RuntimeError(
            "La fuente PNUD no contiene las columnas esperadas: "
            + ", ".join(sorted(missing_columns))
        )

    source_rows: dict[str, dict[str, str]] = {}
    for row in reader:
        code = row["iso3"].strip().upper()
        if code in sample:
            if code in source_rows:
                raise RuntimeError(f"El PNUD repite el país {code}.")
            source_rows[code] = row

    missing_countries = sorted(set(sample).difference(source_rows))
    if missing_countries:
        raise RuntimeError(
            "La fuente PNUD no contiene países DRES: "
            + ", ".join(missing_countries)
        )

    rows: list[dict[str, Any]] = []
    source_names: dict[str, str] = {}
    for code in sorted(sample):
        source_row = source_rows[code]
        source_names[code] = source_row["country"].strip()
        for year in range(START_YEAR, END_YEAR + 1):
            raw_value = source_row[f"mys_{year}"].strip()
            value: float | str = ""
            if raw_value:
                value = float(raw_value)
                if not 0 <= value <= 20:
                    raise RuntimeError(
                        f"MYS fuera de dominio para {code}-{year}: {value}"
                    )
            rows.append(
                {
                    "country_iso3_code": code,
                    "country_dres": sample[code],
                    "country_undp": source_names[code],
                    "year": year,
                    "mean_years_schooling_undp": value,
                    "indicator_code": INDICATOR_CODE,
                    "indicator_name": INDICATOR_NAME,
                    "source_vintage": SOURCE_VINTAGE,
                }
            )
    return rows, source_names


def validate_analysis(rows: list[dict[str, Any]]) -> int:
    """Valida cobertura, llaves y dominio en 1996-2021."""

    analysis_rows = [
        row
        for row in rows
        if ANALYSIS_START_YEAR <= int(row["year"]) <= ANALYSIS_END_YEAR
    ]
    expected = EXPECTED_SAMPLE_COUNTRIES * (
        ANALYSIS_END_YEAR - ANALYSIS_START_YEAR + 1
    )
    if len(analysis_rows) != expected:
        raise RuntimeError("La captura no conserva las 1.430 llaves esperadas.")

    keys = {
        (row["country_iso3_code"], int(row["year"]))
        for row in analysis_rows
    }
    if len(keys) != expected:
        raise RuntimeError("La captura contiene llaves país-año duplicadas.")

    available = sum(
        row["mean_years_schooling_undp"] != "" for row in analysis_rows
    )
    if available < MINIMUM_ANALYSIS_OBSERVATIONS:
        raise RuntimeError(
            "La captura PNUD no alcanza la cobertura mínima requerida."
        )

    countries_with_data = {
        row["country_iso3_code"]
        for row in analysis_rows
        if row["mean_years_schooling_undp"] != ""
    }
    if len(countries_with_data) != EXPECTED_SAMPLE_COUNTRIES:
        raise RuntimeError("Algún país DRES no tiene ningún valor de MYS.")
    return available


def build_pwt_reference(
    source: Path,
    sample: dict[str, str],
) -> list[dict[str, Any]]:
    """Extrae una referencia pequeña desde la base PWT compartida."""

    pwt = pd.read_stata(
        source,
        columns=["countrycode", "country", "year", "hc"],
        convert_categoricals=False,
    )
    pwt["countrycode"] = (
        pwt["countrycode"].astype("string").str.strip().str.upper()
    )
    pwt["year"] = pd.to_numeric(pwt["year"], errors="raise").astype("int64")
    pwt["hc"] = pd.to_numeric(pwt["hc"], errors="coerce").astype("float64")
    selected = pwt[
        pwt["countrycode"].isin(sample)
        & pwt["year"].between(ANALYSIS_START_YEAR, ANALYSIS_END_YEAR)
    ][["countrycode", "year", "hc"]]
    if selected.duplicated(["countrycode", "year"]).any():
        raise RuntimeError("La referencia PWT contiene llaves duplicadas.")

    indexed = selected.set_index(["countrycode", "year"])["hc"]
    rows: list[dict[str, Any]] = []
    for code in sorted(sample):
        for year in range(ANALYSIS_START_YEAR, ANALYSIS_END_YEAR + 1):
            value = indexed.get((code, year), float("nan"))
            rows.append(
                {
                    "country_iso3_code": code,
                    "country": sample[code],
                    "year": year,
                    "humcap_pwt": "" if pd.isna(value) else float(value),
                    "reference_source_code": "PWT11.0:hc",
                }
            )
    if len(rows) != 1430:
        raise RuntimeError("La referencia PWT no conserva 1.430 llaves.")
    if sum(row["humcap_pwt"] != "" for row in rows) != 1222:
        raise RuntimeError("La referencia PWT no conserva 1.222 valores.")
    return rows


def main() -> None:
    """Descarga, transforma a formato largo y documenta la captura."""

    project = find_project_root()
    sample_file = (
        project / "data" / "processed" / "dres" / "dres_sample_20.csv"
    )
    output = project / "data" / "raw" / "humcap" / "undp_hdr"
    pwt_shared_source = project / "data" / "raw" / "pwt" / "pwt110.dta"
    source_output = output / "source_files"
    data_source_file = (
        source_output / "HDR25_Composite_indices_complete_time_series.csv"
    )
    metadata_source_file = (
        source_output / "HDR25_Composite_indices_metadata.xlsx"
    )
    long_file = output / "humcap_undp_mys_input_1990_2023.csv"
    metadata_file = output / "humcap_undp_metadata.csv"
    pwt_reference_file = output / "humcap_pwt11_reference_1996_2021.csv"
    manifest_file = output / "download_manifest.csv"

    sample = read_sample(sample_file)
    if not pwt_shared_source.is_file():
        raise FileNotFoundError(
            f"No se encontró la base PWT compartida: {pwt_shared_source}"
        )
    data_content = download(DATA_URL)
    metadata_content = download(METADATA_URL)
    rows, source_names = parse_source(data_content, sample)
    available = validate_analysis(rows)
    pwt_reference_rows = build_pwt_reference(pwt_shared_source, sample)

    atomic_write_bytes(data_source_file, data_content)
    atomic_write_bytes(metadata_source_file, metadata_content)
    atomic_write_csv(
        long_file,
        [
            "country_iso3_code",
            "country_dres",
            "country_undp",
            "year",
            "mean_years_schooling_undp",
            "indicator_code",
            "indicator_name",
            "source_vintage",
        ],
        rows,
    )
    atomic_write_csv(
        metadata_file,
        [
            "indicator_code",
            "indicator_name",
            "population_scope",
            "unit",
            "source",
            "source_vintage",
            "source_coverage",
            "construction_note",
            "recommended_citation",
            "data_url",
            "metadata_url",
        ],
        [
            {
                "indicator_code": INDICATOR_CODE,
                "indicator_name": INDICATOR_NAME,
                "population_scope": "Adults ages 25 years and older",
                "unit": "Years",
                "source": "United Nations Development Programme",
                "source_vintage": SOURCE_VINTAGE,
                "source_coverage": "1990-2023",
                "construction_note": (
                    "Raw MYS is preserved as published. The PWT-style "
                    "returns transformation is applied only in processed."
                ),
                "recommended_citation": (
                    "UNDP (2025), Human Development Report 2025: "
                    "A matter of choice: People and possibilities in "
                    "the age of AI."
                ),
                "data_url": DATA_URL,
                "metadata_url": METADATA_URL,
            }
        ],
    )
    atomic_write_csv(
        pwt_reference_file,
        [
            "country_iso3_code",
            "country",
            "year",
            "humcap_pwt",
            "reference_source_code",
        ],
        pwt_reference_rows,
    )
    atomic_write_csv(
        manifest_file,
        [
            "retrieved_at_utc",
            "indicator_code",
            "source_vintage",
            "sample_countries",
            "historical_country_years",
            "analysis_country_years",
            "analysis_available",
            "analysis_missing",
            "data_source_sha256",
            "metadata_source_sha256",
            "long_extract_sha256",
            "pwt_shared_source_sha256",
            "pwt_reference_extract_sha256",
            "data_url",
            "metadata_url",
        ],
        [
            {
                "retrieved_at_utc": datetime.now(timezone.utc)
                .replace(microsecond=0)
                .isoformat(),
                "indicator_code": INDICATOR_CODE,
                "source_vintage": SOURCE_VINTAGE,
                "sample_countries": len(source_names),
                "historical_country_years": len(rows),
                "analysis_country_years": 1430,
                "analysis_available": available,
                "analysis_missing": 1430 - available,
                "data_source_sha256": sha256(data_source_file),
                "metadata_source_sha256": sha256(metadata_source_file),
                "long_extract_sha256": sha256(long_file),
                "pwt_shared_source_sha256": sha256(pwt_shared_source),
                "pwt_reference_extract_sha256": sha256(pwt_reference_file),
                "data_url": DATA_URL,
                "metadata_url": METADATA_URL,
            }
        ],
    )

    print(f"Datos raw PNUD guardados en: {long_file}")
    print(f"Archivos fuente guardados en: {source_output}")
    print(
        "Descarga validada: "
        f"{len(source_names)} países, {len(rows)} país-años históricos y "
        f"{available} de 1.430 observaciones disponibles en 1996-2021."
    )


if __name__ == "__main__":
    main()
