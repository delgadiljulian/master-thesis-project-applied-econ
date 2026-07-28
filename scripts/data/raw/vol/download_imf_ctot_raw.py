"""CAPA: RAW.

Descarga tabular del flujo CTOT mediante la API SDMX 3.0 del FMI.
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path
from urllib.request import Request, urlopen


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("Uso: download_imf_ctot_raw.py URL ARCHIVO_DESTINO")

    url = sys.argv[1]
    destination = Path(sys.argv[2])
    destination.parent.mkdir(parents=True, exist_ok=True)

    request = Request(
        url,
        headers={
            "Accept": "text/csv",
            "User-Agent": "master-thesis-project-applied-econ/1.0",
        },
    )
    with urlopen(request, timeout=120) as response:
        if response.status != 200:
            raise RuntimeError(f"La API del FMI respondio {response.status}.")
        with destination.open("wb") as output:
            shutil.copyfileobj(response, output)

    with destination.open("rb") as source:
        header = source.readline()
    if b"STRUCTURE_ID" not in header or b"OBS_VALUE" not in header:
        destination.unlink(missing_ok=True)
        raise RuntimeError("La API del FMI no devolvio el CSV SDMX esperado.")


if __name__ == "__main__":
    main()
