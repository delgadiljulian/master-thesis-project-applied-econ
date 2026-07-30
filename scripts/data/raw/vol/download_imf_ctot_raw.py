"""CAPA: RAW.
FUENTE: Fondo Monetario Internacional, flujo CTOT.
ENTRADAS: URL SDMX 3.0 y ruta de destino recibidas por línea de comandos.
SALIDAS: archivo tabular indicado por el proceso principal de VOL.

# Ejecutar la siguiente instrucción del bloque
Descarga tabular del flujo CTOT mediante la API SDMX 3.0 del FMI.
"""

# Cargar librerías y módulos requeridos
from __future__ import annotations

# Cargar librerías y módulos requeridos
import shutil
import sys
from pathlib import Path
from urllib.request import Request, urlopen


# Definir función principal o auxiliar
def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("Uso: download_imf_ctot_raw.py URL ARCHIVO_DESTINO")

    # Ejecutar la siguiente instrucción del bloque
    url = sys.argv[1]
    destination = Path(sys.argv[2])
    destination.parent.mkdir(parents=True, exist_ok=True)

    # Ejecutar la siguiente instrucción del bloque
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

    # Ejecutar la siguiente instrucción del bloque
    with destination.open("rb") as source:
        header = source.readline()
    if b"STRUCTURE_ID" not in header or b"OBS_VALUE" not in header:
        destination.unlink(missing_ok=True)
        raise RuntimeError("La API del FMI no devolvio el CSV SDMX esperado.")


# Evaluar condición de control de flujo
if __name__ == "__main__":
    main()
