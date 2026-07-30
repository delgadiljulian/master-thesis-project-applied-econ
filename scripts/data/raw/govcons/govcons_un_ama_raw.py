"""CAPA: RAW
VARIABLE: GOVCONS
ENTRADAS: API oficial de Cuentas Nacionales de Naciones Unidas
SALIDAS: data/raw/govcons/un_ama/

# Ejecutar la siguiente instrucción del bloque
Descarga el consumo final del gobierno general como porcentaje del PIB para
los 55 países de la muestra DRES. La capa raw conserva tanto los valores de la
serie 16, componente 3, como los metadatos país-específicos que documentan si
cada tramo proviene de datos oficiales o de procedimientos derivados.
"""

# Cargar librerías y módulos requeridos
from __future__ import annotations

# Cargar librerías y módulos requeridos
import csv
import hashlib
import json
import os
import tempfile
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


# Ejecutar la siguiente instrucción del bloque
API_BASE_URL = "https://unstats.un.org/unsd/amaapi/api"
SERIES_CODE = 16
ITEM_ID = 3
METADATA_GROUP_ID = 101
START_YEAR = 1970
END_YEAR = 2024
ANALYSIS_START_YEAR = 1996
ANALYSIS_END_YEAR = 2021
MAX_ATTEMPTS = 3

# Correspondencia ISO3-M49 de la muestra fija DRES. Los códigos M49 son los
# identificadores que exige la API de Naciones Unidas.
M49_BY_ISO3 = {
    "AGO": 24,
    "ALB": 8,
    "ARE": 784,
    "ATG": 28,
    "AUS": 36,
    "BDI": 108,
    "BHR": 48,
    "BOL": 68,
    "BRN": 96,
    "CAF": 140,
    "CHL": 152,
    "CMR": 120,
    "COD": 180,
    "COG": 178,
    "COL": 170,
    "DZA": 12,
    "ECU": 218,
    "EGY": 818,
    "GAB": 266,
    "GHA": 288,
    "GIN": 324,
    "GMB": 270,
    "GUY": 328,
    "IDN": 360,
    "IND": 356,
    "IRN": 364,
    "IRQ": 368,
    "ISR": 376,
    "JAM": 388,
    "JOR": 400,
    "KWT": 414,
    "LBR": 430,
    "LBY": 434,
    "MNG": 496,
    "MRT": 478,
    "NGA": 566,
    "NOR": 578,
    "NRU": 520,
    "OMN": 512,
    "PER": 604,
    "PNG": 598,
    "QAT": 634,
    "RUS": 643,
    "SAU": 682,
    "SLE": 694,
    "SUR": 740,
    "SYC": 690,
    "SYR": 760,
    "TGO": 768,
    "TTO": 780,
    "VEN": 862,
    "VNM": 704,
    "YEM": 887,
    "ZAF": 710,
    "ZMB": 894,
}


# Definir función principal o auxiliar
def find_project_root() -> Path:
    """Localiza la raíz del repositorio desde la ubicación del script."""

    # Ejecutar la siguiente instrucción del bloque
    candidate = Path(__file__).resolve().parents[4]
    if not (candidate / "scripts" / "project_paths.R").exists():
        raise RuntimeError("No se pudo identificar la raíz del repositorio.")
    return candidate


# Definir función principal o auxiliar
def api_request(path: str, payload: dict[str, Any] | None = None) -> Any:
    """Consulta la API con reintentos y devuelve el JSON validado."""

    # Ejecutar la siguiente instrucción del bloque
    url = f"{API_BASE_URL}/{path.lstrip('/')}"
    encoded_payload = (
        json.dumps(payload, separators=(",", ":")).encode("utf-8")
        if payload is not None
        else None
    )
    request = urllib.request.Request(
        url,
        data=encoded_payload,
        headers={
            "Accept": "application/json",
            "Content-Type": "application/json",
            "User-Agent": (
                "master-thesis-project-applied-econ/"
                "govcons-un-ama-raw-download"
            ),
        },
        method="POST" if payload is not None else "GET",
    )

    # Ejecutar la siguiente instrucción del bloque
    last_error: Exception | None = None
    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                body = response.read().decode("utf-8")
            return json.loads(body)
        except (
            urllib.error.URLError,
            TimeoutError,
            json.JSONDecodeError,
        ) as error:
            last_error = error
            if attempt < MAX_ATTEMPTS:
                time.sleep(2**attempt)

    # Detener la ejecución si no se cumple la condición
    raise RuntimeError(
        f"No fue posible consultar {url} después de "
        f"{MAX_ATTEMPTS} intentos."
    ) from last_error


# Definir función principal o auxiliar
def atomic_write_csv(
    path: Path,
    fieldnames: list[str],
    rows: list[dict[str, Any]],
) -> None:
    """Escribe un CSV completo y reemplaza el destino solo al finalizar."""

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
def sha256(path: Path) -> str:
    """Calcula el hash SHA-256 de una captura guardada."""

    # Retornar el resultado de la función
    return hashlib.sha256(path.read_bytes()).hexdigest()


# Definir función principal o auxiliar
def main() -> None:
    """Descarga y valida la serie y sus metadatos para la muestra DRES."""

    # Ejecutar la siguiente instrucción del bloque
    project_root = find_project_root()
    sample_file = (
        project_root
        / "data"
        / "processed"
        / "dres"
        / "dres_sample_20.csv"
    )
    raw_path = project_root / "data" / "raw" / "govcons" / "un_ama"
    data_file = raw_path / "govcons_un_ama_1970_2024.csv"
    metadata_file = raw_path / "govcons_un_ama_metadata.csv"
    manifest_file = raw_path / "download_manifest.csv"

    # Ejecutar la siguiente instrucción del bloque
    with sample_file.open(newline="", encoding="utf-8-sig") as handle:
        sample_rows = list(csv.DictReader(handle))

    # Ejecutar la siguiente instrucción del bloque
    sample = {
        row["country_iso3_code"].strip().upper(): row["country"].strip()
        for row in sample_rows
    }
    if len(sample) != 55:
        raise RuntimeError("La muestra DRES no contiene 55 países únicos.")

    # Ejecutar la siguiente instrucción del bloque
    missing_m49 = sorted(set(sample) - set(M49_BY_ISO3))
    extra_m49 = sorted(set(M49_BY_ISO3) - set(sample))
    if missing_m49 or extra_m49:
        raise RuntimeError(
            "La correspondencia ISO3-M49 no coincide con la muestra DRES. "
            f"Faltantes: {missing_m49}; adicionales: {extra_m49}."
        )

    # Ejecutar la siguiente instrucción del bloque
    country_catalog = api_request("Country")
    country_by_m49 = {
        int(row["countryCode"]): str(row["countryName"]).strip()
        for row in country_catalog
        if row.get("isCountry")
    }
    missing_un_countries = sorted(
        iso3
        for iso3, m49 in M49_BY_ISO3.items()
        if m49 not in country_by_m49
    )
    if missing_un_countries:
        raise RuntimeError(
            "La API no reconoce los códigos M49 de: "
            + ", ".join(missing_un_countries)
        )

    # Ejecutar la siguiente instrucción del bloque
    series_info = api_request(f"Series/{SERIES_CODE}")
    expected_series_name = "GDP by Expenditure, Percentage Distribution (Shares)"
    if (
        int(series_info["serieCode"]) != SERIES_CODE
        or series_info["serieName"] != expected_series_name
    ):
        raise RuntimeError("La definición de la serie 16 cambió en la API.")

    # Ejecutar la siguiente instrucción del bloque
    years = list(range(START_YEAR, END_YEAR + 1))
    data_response = api_request(
        f"Data/basic/{SERIES_CODE}",
        {
            "paramCodes": [
                M49_BY_ISO3[iso3] for iso3 in sorted(sample)
            ],
            "years": years,
        },
    )
    iso3_by_m49 = {
        m49: iso3 for iso3, m49 in M49_BY_ISO3.items()
    }

    # Ejecutar la siguiente instrucción del bloque
    data_rows: list[dict[str, Any]] = []
    for observation in data_response:
        if int(observation.get("itemId", -1)) != ITEM_ID:
            continue
        m49 = int(observation["countryCode"])
        iso3 = iso3_by_m49.get(m49)
        year = int(observation["fiscalYear"])
        if iso3 is None or not (START_YEAR <= year <= END_YEAR):
            continue
        value = observation.get("observationValue")
        if value is None:
            continue
        numeric_value = float(value)
        if not numeric_value > 0:
            raise RuntimeError(
                f"Valor no positivo para {iso3}-{year}: {numeric_value}."
            )
        data_rows.append(
            {
                "country_iso3_code": iso3,
                "country_m49": m49,
                "country_un": str(observation["countryName"]).strip(),
                "year": year,
                "government_consumption_pct_gdp_un": repr(numeric_value),
                "series_code": int(observation["serieCode"]),
                "series_name": str(observation["serieName"]).strip(),
                "item_id": int(observation["itemId"]),
                "item_name": str(observation["itemName"]).strip(),
                "api_unit": str(observation.get("unit") or "").strip(),
            }
        )

    # Ejecutar la siguiente instrucción del bloque
    data_rows.sort(
        key=lambda row: (row["country_iso3_code"], row["year"])
    )
    data_keys = [
        (row["country_iso3_code"], row["year"]) for row in data_rows
    ]
    if len(data_keys) != len(set(data_keys)):
        raise RuntimeError("La captura ONU contiene llaves país-año duplicadas.")

    # Ejecutar la siguiente instrucción del bloque
    analysis_keys = {
        key
        for key in data_keys
        if ANALYSIS_START_YEAR <= key[1] <= ANALYSIS_END_YEAR
    }
    expected_analysis_keys = {
        (iso3, year)
        for iso3 in sample
        for year in range(ANALYSIS_START_YEAR, ANALYSIS_END_YEAR + 1)
    }
    if analysis_keys != expected_analysis_keys:
        missing_keys = sorted(expected_analysis_keys - analysis_keys)
        raise RuntimeError(
            "La serie ONU no cubre completamente 1996-2021. "
            f"Primeras llaves faltantes: {missing_keys[:10]}"
        )

    # Ejecutar la siguiente instrucción del bloque
    metadata_rows: list[dict[str, Any]] = []
    for iso3 in sorted(sample):
        m49 = M49_BY_ISO3[iso3]
        metadata_response = api_request(
            f"Metadata/{m49}/{METADATA_GROUP_ID}"
        )
        relevant_metadata = [
            row
            for row in metadata_response
            if row.get("indicatorName")
            == "General government final consumption expenditure"
        ]
        if not relevant_metadata:
            raise RuntimeError(
                f"La API no devolvió metadatos GOVCONS para {iso3}."
            )
        for row in relevant_metadata:
            metadata_rows.append(
                {
                    "country_iso3_code": iso3,
                    "country_m49": m49,
                    "country_un": country_by_m49[m49],
                    "metadata_group_id": int(row["groupId"]),
                    "metadata_item_id": int(row["itemId"]),
                    "indicator_name": str(row["indicatorName"]).strip(),
                    "years": str(row["years"]).strip(),
                    "organisation_name": str(
                        row.get("organisationName") or ""
                    ).strip(),
                    "publication_name": str(
                        row.get("publicationName") or ""
                    ).strip(),
                    "method_name": str(
                        row.get("methodName") or ""
                    ).strip(),
                }
            )

    # Ejecutar la siguiente instrucción del bloque
    metadata_rows.sort(
        key=lambda row: (
            row["country_iso3_code"],
            row["years"],
            row["publication_name"],
            row["method_name"],
        )
    )

    # Ejecutar la siguiente instrucción del bloque
    data_fields = [
        "country_iso3_code",
        "country_m49",
        "country_un",
        "year",
        "government_consumption_pct_gdp_un",
        "series_code",
        "series_name",
        "item_id",
        "item_name",
        "api_unit",
    ]
    metadata_fields = [
        "country_iso3_code",
        "country_m49",
        "country_un",
        "metadata_group_id",
        "metadata_item_id",
        "indicator_name",
        "years",
        "organisation_name",
        "publication_name",
        "method_name",
    ]
    atomic_write_csv(data_file, data_fields, data_rows)
    atomic_write_csv(metadata_file, metadata_fields, metadata_rows)

    # Ejecutar la siguiente instrucción del bloque
    last_updated = api_request("Data/lastupdated")
    retrieved_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    manifest_rows = [
        {
            "retrieved_at_utc": retrieved_at,
            "source_last_updated": str(last_updated),
            "api_base_url": API_BASE_URL,
            "data_endpoint": f"Data/basic/{SERIES_CODE}",
            "metadata_endpoint_pattern": (
                f"Metadata/{{country_m49}}/{METADATA_GROUP_ID}"
            ),
            "series_code": SERIES_CODE,
            "item_id": ITEM_ID,
            "start_year": START_YEAR,
            "end_year": END_YEAR,
            "analysis_start_year": ANALYSIS_START_YEAR,
            "analysis_end_year": ANALYSIS_END_YEAR,
            "sample_countries": len(sample),
            "downloaded_country_years": len(data_rows),
            "analysis_country_years": len(analysis_keys),
            "metadata_rows": len(metadata_rows),
            "data_sha256": sha256(data_file),
            "metadata_sha256": sha256(metadata_file),
        }
    ]
    manifest_fields = list(manifest_rows[0])
    atomic_write_csv(manifest_file, manifest_fields, manifest_rows)

    # Ejecutar la siguiente instrucción del bloque
    print(f"Datos raw ONU guardados en: {data_file}")
    print(f"Metadatos ONU guardados en: {metadata_file}")
    print(f"Manifiesto guardado en: {manifest_file}")
    print(
        "Descarga validada: "
        f"{len(sample)} países, {len(data_rows)} país-años históricos y "
        f"{len(analysis_keys)} de 1.430 país-años en 1996-2021."
    )


# Evaluar condición de control de flujo
if __name__ == "__main__":
    main()
