"""Punto de entrada estable para la captura raw activa de HUMCAP.

La definición activa procede del PNUD. El nombre de este archivo se conserva
para no romper llamadas anteriores.
"""

from pathlib import Path
import runpy


active_script = Path(__file__).with_name("humcap_undp_raw.py")
if not active_script.is_file():
    raise FileNotFoundError(f"No se encontró {active_script}")
runpy.run_path(str(active_script), run_name="__main__")
