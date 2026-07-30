"""CAPA: RAW
VARIABLE: FIN
ENTRADA: descarga oficial de World Development Indicators
SALIDAS: data/raw/fin/world_bank_wdi/

# Ejecutar la siguiente instrucción del bloque
Descarga el crédito doméstico al sector privado otorgado por bancos como
porcentaje del PIB (FD.AST.PRVT.GD.ZS). La captura conserva la cuadrícula de
los 55 países DRES para 1980-2025, los metadatos del indicador, el ZIP oficial
y un manifiesto con hashes SHA-256.
"""

# Cargar librerías y módulos requeridos
from __future__ import annotations

# Cargar librerías y módulos requeridos
import csv
import hashlib
import io
import os
import shutil
import tempfile
import time
import urllib.error
import urllib.request
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


# Ejecutar la siguiente instrucción del bloque
INDICATOR_CODE = "FD.AST.PRVT.GD.ZS"
INDICATOR_NAME = "Domestic credit to private sector by banks (% of GDP)"
DOWNLOAD_URL = (
    "https://api.worldbank.org/v2/en/indicator/"
    f"{INDICATOR_CODE}?downloadformat=csv"
)
START_YEAR = 1980
END_YEAR = 2025
ANALYSIS_START_YEAR = 1996
ANALYSIS_END_YEAR = 2021
EXPECTED_SAMPLE_COUNTRIES = 55
MINIMUM_ANALYSIS_OBSERVATIONS = 1300
MAX_ATTEMPTS = 3


# Definir función principal o auxiliar
def find_project_root() -> Path:
    """Localiza la raíz del repositorio desde la ubicación del script."""

    # Ejecutar la siguiente instrucción del bloque
    candidate = Path(__file__).resolve().parents[4]
    if not (candidate / "scripts" / "project_paths.R").exists():
        raise RuntimeError("No se pudo identificar la raíz del repositorio.")
    return candidate


# Definir función principal o auxiliar
def sha256(path: Path) -> str:
    """Calcula el hash SHA-256 de un archivo."""

    # Retornar el resultado de la función
    return hashlib.sha256(path.read_bytes()).hexdigest()


# Definir función principal o auxiliar
def atomic_write_csv(
    path: Path,
    fieldnames: list[str],
    rows: list[dict[str, Any]],
) -> None:
    """Escribe un CSV completo y reemplaza el destino al finalizar."""

    # Ejecutar la siguiente instrucción del bloque
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f"{path.stem}_",
        suffix=".tmp",
        dir=path.parent,
        text=True,
    )
    try:
        with os.fdopen(descriptor, "w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(rows)
        os.replace(temporary_name, path)
    except Exception:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)
        raise


# Definir función principal o auxiliar
def download_archive(destination: Path) -> None:
    """Descarga el ZIP oficial con reintentos y reemplazo atómico."""

    # Ejecutar la siguiente instrucción del bloque
    destination.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f"{destination.stem}_",
        suffix=".tmp",
        dir=destination.parent,
    )
    os.close(descriptor)
    request = urllib.request.Request(
        DOWNLOAD_URL,
        headers={
            "Accept": "application/zip,application/octet-stream",
            "User-Agent": (
                "master-thesis-project-applied-econ/"
                "fin-wdi-banks-raw-download"
            ),
        },
    )

    # Ejecutar la siguiente instrucción del bloque
    last_error: Exception | None = None
    try:
        for attempt in range(1, MAX_ATTEMPTS + 1):
            try:
                with urllib.request.urlopen(request, timeout=180) as response:
                    with open(temporary_name, "wb") as handle:
                        shutil.copyfileobj(response, handle)
                if not zipfile.is_zipfile(temporary_name):
                    raise RuntimeError(
                        "La respuesta del Banco Mundial no es un ZIP válido."
                    )
                os.replace(temporary_name, destination)
                return
            except (
                urllib.error.URLError,
                TimeoutError,
                OSError,
                RuntimeError,
            ) as error:
                last_error = error
                if attempt < MAX_ATTEMPTS:
                    time.sleep(2**attempt)
        raise RuntimeError(
            "No fue posible descargar la serie WDI después de "
            f"{MAX_ATTEMPTS} intentos."
        ) from last_error
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)


# Definir función principal o auxiliar
def find_zip_member(
    archive: zipfile.ZipFile,
    prefix: str,
) -> str:
    """Encuentra exactamente un archivo CSV por prefijo."""

    # Ejecutar la siguiente instrucción del bloque
    matches = [
        name
        for name in archive.namelist()
        if Path(name).name.startswith(prefix)
        and Path(name).suffix.lower() == ".csv"
    ]
    if len(matches) != 1:
        raise RuntimeError(
            f"Se esperaba un archivo con prefijo {prefix} y se encontraron "
            f"{len(matches)}."
        )
    return matches[0]


# Definir función principal o auxiliar
def read_sample(sample_file: Path) -> dict[str, str]:
    """Lee y valida la muestra fija DRES."""

    # Ejecutar la siguiente instrucción del bloque
    with sample_file.open(newline="", encoding="utf-8-sig") as handle:
        rows = list(csv.DictReader(handle))
    sample = {
        row["country_iso3_code"].strip().upper(): row["country"].strip()
        for row in rows
    }
    if len(sample) != EXPECTED_SAMPLE_COUNTRIES:
        raise RuntimeError("La muestra DRES no contiene 55 países únicos.")
    if any(len(code) != 3 or not code.isalpha() for code in sample):
        raise RuntimeError("La muestra DRES contiene códigos ISO3 inválidos.")
    return sample


# Definir función principal o auxiliar
def read_wdi_rows(
    archive: zipfile.ZipFile,
    data_member: str,
    sample: dict[str, str],
) -> list[dict[str, Any]]:
    """Convierte el archivo WDI ancho en una cuadrícula país-año."""

    # Ejecutar la siguiente instrucción del bloque
    with archive.open(data_member) as binary_handle:
        text_handle = io.TextIOWrapper(binary_handle, encoding="utf-8-sig")
        for _ in range(4):
            next(text_handle)
        source_rows = list(csv.DictReader(text_handle))

    # Ejecutar la siguiente instrucción del bloque
    rows_by_iso3 = {
        str(row["Country Code"]).strip().upper(): row
        for row in source_rows
        if str(row.get("Indicator Code") or "").strip() == INDICATOR_CODE
    }
    missing_countries = sorted(set(sample) - set(rows_by_iso3))
    if missing_countries:
        raise RuntimeError(
            "La descarga WDI no incluye: " + ", ".join(missing_countries)
        )

    # Ejecutar la siguiente instrucción del bloque
    data_rows: list[dict[str, Any]] = []
    for iso3 in sorted(sample):
        source_row = rows_by_iso3[iso3]
        if str(source_row["Indicator Name"]).strip() != INDICATOR_NAME:
            raise RuntimeError(
                f"Cambió el nombre oficial del indicador para {iso3}."
            )
        for year in range(START_YEAR, END_YEAR + 1):
            raw_value = str(source_row.get(str(year)) or "").strip()
            value: str | float = ""
            if raw_value:
                numeric_value = float(raw_value)
                if not numeric_value >= 0:
                    raise RuntimeError(
                        f"Valor negativo para {iso3}-{year}: {numeric_value}."
                    )
                value = repr(numeric_value)
            data_rows.append(
                {
                    "country_iso3_code": iso3,
                    "country_dres": sample[iso3],
                    "country_wdi": str(source_row["Country Name"]).strip(),
                    "year": year,
                    "domestic_credit_private_banks_pct_gdp": value,
                    "indicator_code": INDICATOR_CODE,
                    "indicator_name": INDICATOR_NAME,
                }
            )

    # Ejecutar la siguiente instrucción del bloque
    keys = [
        (row["country_iso3_code"], row["year"])
        for row in data_rows
    ]
    expected_rows = (
        EXPECTED_SAMPLE_COUNTRIES * (END_YEAR - START_YEAR + 1)
    )
    if len(data_rows) != expected_rows or len(keys) != len(set(keys)):
        raise RuntimeError(
            "La cuadrícula WDI histórica no conserva llaves únicas."
        )

    # Ejecutar la siguiente instrucción del bloque
    analysis_rows = [
        row
        for row in data_rows
        if ANALYSIS_START_YEAR <= row["year"] <= ANALYSIS_END_YEAR
    ]
    available_analysis_rows = sum(
        row["domestic_credit_private_banks_pct_gdp"] != ""
        for row in analysis_rows
    )
    if len(analysis_rows) != EXPECTED_SAMPLE_COUNTRIES * 26:
        raise RuntimeError("La cuadrícula WDI no contiene 1.430 país-años.")
    if available_analysis_rows < MINIMUM_ANALYSIS_OBSERVATIONS:
        raise RuntimeError(
            "La cobertura bancaria WDI cayó por debajo de 1.300 país-años."
        )

    # Retornar el resultado de la función
    return data_rows


# Definir función principal o auxiliar
def read_metadata(
    archive: zipfile.ZipFile,
    metadata_member: str,
) -> list[dict[str, Any]]:
    """Conserva los metadatos oficiales del indicador."""

    # Ejecutar la siguiente instrucción del bloque
    with archive.open(metadata_member) as binary_handle:
        text_handle = io.TextIOWrapper(binary_handle, encoding="utf-8-sig")
        rows = list(csv.DictReader(text_handle))
    relevant = [
        row
        for row in rows
        if str(row.get("INDICATOR_CODE") or "").strip() == INDICATOR_CODE
    ]
    if len(relevant) != 1:
        raise RuntimeError(
            "Los metadatos WDI no contienen una única fila del indicador."
        )
    row = relevant[0]
    return [
        {
            "indicator_code": str(row.get("INDICATOR_CODE") or "").strip(),
            "indicator_name": str(row.get("INDICATOR_NAME") or "").strip(),
            "source_note": str(row.get("SOURCE_NOTE") or "").strip(),
            "source_organization": str(
                row.get("SOURCE_ORGANIZATION") or ""
            ).strip(),
        }
    ]


# Definir función principal o auxiliar
def main() -> None:
    """Descarga, normaliza y valida la nueva definición activa de FIN."""

    # Ejecutar la siguiente instrucción del bloque
    project_root = find_project_root()
    sample_file = (
        project_root
        / "data"
        / "processed"
        / "dres"
        / "dres_sample_20.csv"
    )
    raw_path = project_root / "data" / "raw" / "fin" / "world_bank_wdi"
    source_path = raw_path / "source_zip"
    zip_file = source_path / "FD_AST_PRVT_GD_ZS.zip"
    data_file = raw_path / "fin_banks_wdi_input_1980_2025.csv"
    metadata_file = raw_path / "fin_banks_wdi_metadata.csv"
    manifest_file = raw_path / "download_manifest.csv"

    # Ejecutar la siguiente instrucción del bloque
    sample = read_sample(sample_file)
    download_archive(zip_file)

    # Ejecutar la siguiente instrucción del bloque
    with zipfile.ZipFile(zip_file) as archive:
        data_member = find_zip_member(
            archive,
            f"API_{INDICATOR_CODE}_DS2_en_csv",
        )
        metadata_member = find_zip_member(
            archive,
            f"Metadata_Indicator_API_{INDICATOR_CODE}_DS2_en_csv",
        )
        data_rows = read_wdi_rows(archive, data_member, sample)
        metadata_rows = read_metadata(archive, metadata_member)
        latest_entry_timestamp = max(
            datetime(*entry.date_time, tzinfo=timezone.utc)
            for entry in archive.infolist()
        ).isoformat()

    # Ejecutar la siguiente instrucción del bloque
    data_fields = [
        "country_iso3_code",
        "country_dres",
        "country_wdi",
        "year",
        "domestic_credit_private_banks_pct_gdp",
        "indicator_code",
        "indicator_name",
    ]
    metadata_fields = [
        "indicator_code",
        "indicator_name",
        "source_note",
        "source_organization",
    ]
    atomic_write_csv(data_file, data_fields, data_rows)
    atomic_write_csv(metadata_file, metadata_fields, metadata_rows)

    # Ejecutar la siguiente instrucción del bloque
    analysis_rows = [
        row
        for row in data_rows
        if ANALYSIS_START_YEAR <= row["year"] <= ANALYSIS_END_YEAR
    ]
    available_analysis_rows = sum(
        row["domestic_credit_private_banks_pct_gdp"] != ""
        for row in analysis_rows
    )
    retrieved_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    manifest_rows = [
        {
            "retrieved_at_utc": retrieved_at,
            "source_archive_latest_entry_utc": latest_entry_timestamp,
            "download_url": DOWNLOAD_URL,
            "indicator_code": INDICATOR_CODE,
            "indicator_name": INDICATOR_NAME,
            "source_data_member": data_member,
            "source_metadata_member": metadata_member,
            "start_year": START_YEAR,
            "end_year": END_YEAR,
            "analysis_start_year": ANALYSIS_START_YEAR,
            "analysis_end_year": ANALYSIS_END_YEAR,
            "sample_countries": len(sample),
            "historical_country_years": len(data_rows),
            "analysis_country_years": len(analysis_rows),
            "available_analysis_country_years": available_analysis_rows,
            "missing_analysis_country_years": (
                len(analysis_rows) - available_analysis_rows
            ),
            "coverage_percent_1996_2021": (
                100 * available_analysis_rows / len(analysis_rows)
            ),
            "zip_sha256": sha256(zip_file),
            "data_sha256": sha256(data_file),
            "metadata_sha256": sha256(metadata_file),
        }
    ]
    atomic_write_csv(
        manifest_file,
        list(manifest_rows[0]),
        manifest_rows,
    )

    # Ejecutar la siguiente instrucción del bloque
    print(f"Datos raw WDI guardados en: {data_file}")
    print(f"Metadatos WDI guardados en: {metadata_file}")
    print(f"ZIP oficial guardado en: {zip_file}")
    print(f"Manifiesto guardado en: {manifest_file}")
    print(
        "Descarga validada: "
        f"{len(sample)} países, {len(data_rows)} país-años históricos y "
        f"{available_analysis_rows} de 1.430 observaciones disponibles "
        "en 1996-2021."
    )


# Evaluar condición de control de flujo
if __name__ == "__main__":
    main()
