"""CAPA: RAW
VARIABLE: ECI
ENTRADAS: API GraphQL oficial del Atlas of Economic Complexity
SALIDAS: data/raw/eci/atlas/

Descarga una captura reproducible de la serie countryYear.eci publicada por el
Harvard Growth Lab. La capa raw conserva los valores entregados por la API sin
imputación, interpolación, redondeo ni transformación.
"""

from __future__ import annotations

import csv
import hashlib
import json
import os
import re
import tempfile
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


API_URL = "https://atlas.hks.harvard.edu/api/graphql"
START_YEAR = 1995
END_YEAR = 2022
BATCH_SIZE = 40
MAX_ATTEMPTS = 3


def find_project_root() -> Path:
    """Localiza la raíz del repositorio desde la ubicación de este script."""

    candidate = Path(__file__).resolve().parents[4]
    if not (candidate / "scripts" / "project_paths.R").exists():
        raise RuntimeError("No se pudo identificar la raíz del repositorio.")
    return candidate


def graphql_request(query: str) -> dict[str, Any]:
    """Ejecuta una consulta GraphQL y valida la respuesta antes de usarla."""

    payload = json.dumps({"query": query}).encode("utf-8")
    request = urllib.request.Request(
        API_URL,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "User-Agent": "master-thesis-project-applied-econ/eci-raw-download",
        },
        method="POST",
    )

    last_error: Exception | None = None
    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                result = json.loads(response.read().decode("utf-8"))
            if result.get("errors"):
                raise RuntimeError(
                    "La API devolvió errores GraphQL: "
                    + json.dumps(result["errors"], ensure_ascii=False)
                )
            if "data" not in result:
                raise RuntimeError("La respuesta GraphQL no contiene el campo data.")
            return result["data"]
        except (urllib.error.URLError, TimeoutError, RuntimeError) as error:
            last_error = error
            if attempt < MAX_ATTEMPTS:
                time.sleep(2**attempt)

    raise RuntimeError(
        f"No fue posible consultar la API después de {MAX_ATTEMPTS} intentos."
    ) from last_error


def atomic_write_csv(
    path: Path,
    fieldnames: list[str],
    rows: list[dict[str, Any]],
) -> None:
    """Escribe un CSV completo y solo reemplaza el destino al finalizar."""

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


def main() -> None:
    """Descarga el catálogo de países y sus observaciones anuales de ECI."""

    project_root = find_project_root()
    raw_path = project_root / "data" / "raw" / "eci" / "atlas"
    data_file = raw_path / "atlas_eci_country_year_1995_2022.csv"
    metadata_file = raw_path / "atlas_eci_api_metadata.csv"

    location_query = """
    {
      locationCountry {
        countryId
        iso3Code
        nameEn
      }
    }
    """
    locations_raw = graphql_request(location_query)["locationCountry"]

    locations: list[dict[str, Any]] = []
    for location in locations_raw:
        iso3 = str(location.get("iso3Code", "")).strip().upper()
        country_id_text = str(location.get("countryId", "")).strip()
        country_id_match = re.search(r"(\d+)$", country_id_text)
        if not re.fullmatch(r"[A-Z]{3}", iso3) or country_id_match is None:
            continue
        locations.append(
            {
                "atlas_country_id": country_id_text,
                "country_id_numeric": int(country_id_match.group(1)),
                "country_iso3_code": iso3,
                "country_atlas": str(location.get("nameEn", "")).strip(),
            }
        )

    locations.sort(key=lambda row: row["country_iso3_code"])
    iso3_codes = [row["country_iso3_code"] for row in locations]
    if len(iso3_codes) != len(set(iso3_codes)):
        raise RuntimeError("El catálogo Atlas contiene códigos ISO3 duplicados.")

    rows: list[dict[str, Any]] = []
    for batch_start in range(0, len(locations), BATCH_SIZE):
        batch = locations[batch_start : batch_start + BATCH_SIZE]
        query_fields = []
        alias_to_location: dict[str, dict[str, Any]] = {}
        for location in batch:
            alias = f"c_{location['country_iso3_code'].lower()}"
            alias_to_location[alias] = location
            query_fields.append(
                (
                    f"{alias}: countryYear("
                    f"countryId: {location['country_id_numeric']}, "
                    f"yearMin: {START_YEAR}, yearMax: {END_YEAR}"
                    ") { year eci }"
                )
            )

        batch_query = "{ " + " ".join(query_fields) + " }"
        batch_data = graphql_request(batch_query)

        for alias, location in alias_to_location.items():
            observations = batch_data.get(alias) or []
            for observation in observations:
                year = int(observation["year"])
                if START_YEAR <= year <= END_YEAR:
                    rows.append(
                        {
                            "atlas_country_id": location["atlas_country_id"],
                            "country_iso3_code": location["country_iso3_code"],
                            "country_atlas": location["country_atlas"],
                            "year": year,
                            "eci": observation.get("eci"),
                        }
                    )

    rows.sort(key=lambda row: (row["country_iso3_code"], row["year"]))
    keys = [
        (row["country_iso3_code"], row["year"])
        for row in rows
    ]
    if len(keys) != len(set(keys)):
        raise RuntimeError("La descarga contiene llaves país-año duplicadas.")
    if any(not (START_YEAR <= row["year"] <= END_YEAR) for row in rows):
        raise RuntimeError("La descarga contiene años fuera del intervalo solicitado.")

    fieldnames = [
        "atlas_country_id",
        "country_iso3_code",
        "country_atlas",
        "year",
        "eci",
    ]
    atomic_write_csv(data_file, fieldnames, rows)

    digest = hashlib.sha256(data_file.read_bytes()).hexdigest()
    retrieved_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    nonmissing_count = sum(row["eci"] is not None for row in rows)
    metadata_rows = [
        {
            "retrieved_at_utc": retrieved_at,
            "api_endpoint": API_URL,
            "graphql_field": "countryYear.eci",
            "start_year": START_YEAR,
            "end_year": END_YEAR,
            "catalog_countries": len(locations),
            "downloaded_country_years": len(rows),
            "nonmissing_eci_country_years": nonmissing_count,
            "sha256": digest,
        }
    ]
    atomic_write_csv(
        metadata_file,
        [
            "retrieved_at_utc",
            "api_endpoint",
            "graphql_field",
            "start_year",
            "end_year",
            "catalog_countries",
            "downloaded_country_years",
            "nonmissing_eci_country_years",
            "sha256",
        ],
        metadata_rows,
    )

    print(f"Datos ECI raw guardados en: {data_file}")
    print(f"Metadatos de descarga guardados en: {metadata_file}")
    print(
        f"Descarga validada: {len(locations)} países del catálogo, "
        f"{len(rows)} filas y {nonmissing_count} valores ECI observados."
    )


if __name__ == "__main__":
    main()
