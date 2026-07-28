"""CAPA: RAW.

Descarga un ZIP oficial de WDI usando la biblioteca estandar de Python.
"""

from pathlib import Path
import shutil
import sys
from urllib.request import Request, urlopen


def main() -> None:
    """Descarga el archivo y confirma que tenga una cabecera ZIP valida."""

    if len(sys.argv) != 3:
        raise SystemExit("Uso: download_wdi_zip_raw.py URL ARCHIVO_DESTINO")

    url = sys.argv[1]
    destination = Path(sys.argv[2])
    destination.parent.mkdir(parents=True, exist_ok=True)

    request = Request(
        url,
        headers={"User-Agent": "master-thesis-project-applied-econ/1.0"},
    )
    with urlopen(request, timeout=120) as response:
        if response.status != 200:
            raise RuntimeError(
                f"El Banco Mundial respondio {response.status}."
            )
        with destination.open("wb") as output:
            shutil.copyfileobj(response, output)

    with destination.open("rb") as source:
        header = source.read(4)
    if not header.startswith(b"PK"):
        destination.unlink(missing_ok=True)
        raise RuntimeError("La descarga del Banco Mundial no es un ZIP valido.")


if __name__ == "__main__":
    main()
