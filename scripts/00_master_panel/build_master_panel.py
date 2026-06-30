"""
Build the thesis master country-year panel from local processed/raw sources.

The script uses project-relative paths and does not download data. It creates a
full ECI-based panel and a resource-dependent subset identified from the current
commodity-specialization file.
"""

from __future__ import annotations

import re
from pathlib import Path

import numpy as np
import pandas as pd


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "data" / "raw"
RAW_RENTS = RAW / "rents" / "world_bank_wdi"
RAW_INST = RAW / "inst" / "world_bank_wgi"
RAW_RER = RAW / "rer" / "world_bank_wdi"
RAW_HUMCAP_WDI = RAW / "humcap" / "world_bank_wdi"
RAW_HUMCAP_PWT = RAW / "humcap" / "pwt"
RAW_INNOV = RAW / "innov" / "world_bank_wdi"
RAW_GDPPC = RAW / "gdppc" / "world_bank_wdi"
RAW_FISC = RAW / "fisc" / "world_bank_wdi"
RAW_FIN = RAW / "fin" / "world_bank_wdi"
PROCESSED = ROOT / "data" / "processed"
PROCESSED_ECI = PROCESSED / "eci" / "atlas"
PROCESSED_DRES = PROCESSED / "dres" / "anne2021_specialization"
PROCESSED_VOL = PROCESSED / "vol" / "world_bank_pink_sheet"
MASTER_PANEL = PROCESSED / "00_master_panel"
TABLES = ROOT / "outputs" / "tables"

START_YEAR = 1996
END_YEAR = 2022


def read_stata(path: Path) -> pd.DataFrame:
    return pd.read_stata(path, convert_categoricals=False)


def clean_country_year(df: pd.DataFrame, value_cols: list[str]) -> pd.DataFrame:
    cols = ["country_iso3_code", "country", "year", *value_cols]
    out = df.loc[:, cols].copy()
    out["country_iso3_code"] = out["country_iso3_code"].astype(str).str.upper()
    out["year"] = pd.to_numeric(out["year"], errors="coerce").astype("Int64")
    out = out.dropna(subset=["country_iso3_code", "year"])
    return out.drop_duplicates(["country_iso3_code", "year"])


def merge_indicator(
    panel: pd.DataFrame,
    path: Path,
    value_cols: list[str],
    suffix: str,
) -> pd.DataFrame:
    df = clean_country_year(read_stata(path), value_cols)
    df = df.drop(columns=["country"])
    return panel.merge(
        df,
        on=["country_iso3_code", "year"],
        how="left",
        validate="one_to_one",
        suffixes=("", suffix),
    )


def build_institutions() -> pd.DataFrame:
    inst = read_stata(RAW_INST / "inst_raw.dta")

    year_cols = [c for c in inst.columns if re.match(r"x\d{4}_yr\d{4}$", c)]
    keep_codes = {
        "GOV_WGI_CC.EST": "INST_CC",
        "GOV_WGI_RL.EST": "INST_RL",
    }

    inst = inst[inst["series_code"].isin(keep_codes)].copy()
    long = inst.melt(
        id_vars=["country_name", "country_code", "series_code"],
        value_vars=year_cols,
        var_name="year_raw",
        value_name="value",
    )
    long["year"] = long["year_raw"].str.extract(r"x(\d{4})_").astype(int)
    long["variable"] = long["series_code"].map(keep_codes)
    long["value"] = pd.to_numeric(long["value"], errors="coerce")

    wide = (
        long.pivot_table(
            index=["country_code", "country_name", "year"],
            columns="variable",
            values="value",
            aggfunc="first",
        )
        .reset_index()
        .rename(
            columns={
                "country_code": "country_iso3_code",
                "country_name": "country_inst",
            }
        )
    )

    for col in ["INST_CC", "INST_RL"]:
        if col not in wide.columns:
            wide[col] = np.nan

    wide["INST"] = wide[["INST_CC", "INST_RL"]].mean(axis=1)
    return wide[["country_iso3_code", "year", "INST_CC", "INST_RL", "INST"]]


def build_resource_profile() -> pd.DataFrame:
    spec = read_stata(PROCESSED_DRES / "commodity_specialization.dta")
    spec = spec.rename(columns={"iso3": "country_iso3_code"})
    spec["country_iso3_code"] = spec["country_iso3_code"].astype(str).str.upper()
    spec.loc[spec["country"].eq("Angola"), "country_iso3_code"] = "AGO"

    shock = pd.read_csv(PROCESSED_VOL / "country_shock_exposure_index.csv")
    shock = shock[["country", "shock_exposure_variance", "shock_exposure_sd"]]

    profile = spec.merge(shock, on="country", how="left", validate="one_to_one")
    profile = profile.rename(
        columns={
            "country": "resource_profile_country",
            "income_group": "income_group_anne2021",
            "commodities": "extractive_exports_share",
            "main_commodities": "main_extractive_commodities",
        }
    )

    profile["resource_dependent_sample"] = 1
    profile["dres_40_reference"] = (
        profile["extractive_exports_share"] >= 40
    ).astype("Int64")
    profile["dres_50_reference"] = (
        profile["extractive_exports_share"] >= 50
    ).astype("Int64")
    profile["dres_60_reference"] = (
        profile["extractive_exports_share"] >= 60
    ).astype("Int64")

    return profile[
        [
            "country_iso3_code",
            "resource_profile_country",
            "income_group_anne2021",
            "mining",
            "energy",
            "extractive_exports_share",
            "other_exports",
            "resource_type",
            "main_extractive_commodities",
            "shock_exposure_variance",
            "shock_exposure_sd",
            "resource_dependent_sample",
            "dres_40_reference",
            "dres_50_reference",
            "dres_60_reference",
        ]
    ].drop_duplicates("country_iso3_code")


def write_outputs(panel: pd.DataFrame) -> None:
    MASTER_PANEL.mkdir(parents=True, exist_ok=True)
    TABLES.mkdir(parents=True, exist_ok=True)

    panel = panel.sort_values(["country_iso3_code", "year"]).reset_index(drop=True)
    resource_panel = panel[panel["resource_dependent_sample"].eq(1)].copy()

    panel.to_csv(MASTER_PANEL / "master_panel_country_year.csv", index=False)
    resource_panel.to_csv(
        MASTER_PANEL / "master_panel_resource_dependent_country_year.csv",
        index=False,
    )

    panel.to_stata(
        MASTER_PANEL / "master_panel_country_year.dta",
        write_index=False,
        version=118,
    )
    resource_panel.to_stata(
        MASTER_PANEL / "master_panel_resource_dependent_country_year.dta",
        write_index=False,
        version=118,
    )

    diagnostics = pd.DataFrame(
        {
            "metric": [
                "full_panel_rows",
                "full_panel_countries",
                "resource_panel_rows",
                "resource_panel_countries",
                "start_year",
                "end_year",
            ],
            "value": [
                len(panel),
                panel["country_iso3_code"].nunique(),
                len(resource_panel),
                resource_panel["country_iso3_code"].nunique(),
                START_YEAR,
                END_YEAR,
            ],
        }
    )
    diagnostics.to_csv(TABLES / "master_panel_diagnostics.csv", index=False)

    coverage_cols = [
        "eci_hs92",
        "RES_RENT",
        "GDPPC",
        "FIN",
        "RER",
        "HUMCAP_WDI",
        "HUMCAP_PWT",
        "PATENTS",
        "FISC",
        "INST",
        "shock_exposure_sd",
    ]
    coverage = []
    for source_name, df in [
        ("full_panel", panel),
        ("resource_panel", resource_panel),
    ]:
        for col in coverage_cols:
            coverage.append(
                {
                    "panel": source_name,
                    "variable": col,
                    "non_missing": int(df[col].notna().sum()),
                    "missing": int(df[col].isna().sum()),
                    "non_missing_share": round(float(df[col].notna().mean()), 4),
                }
            )
    pd.DataFrame(coverage).to_csv(
        TABLES / "master_panel_variable_coverage.csv",
        index=False,
    )


def main() -> None:
    eci = read_stata(PROCESSED_ECI / "eci_data.dta")
    eci = eci[
        [
            "country_id",
            "country_iso3_code",
            "year",
            "in_rankings",
            "eci_sitc",
            "eci_rank_sitc",
            "eci_hs92",
            "eci_rank_hs92",
            "eci_hs12",
            "eci_rank_hs12",
        ]
    ].copy()
    eci["country_iso3_code"] = eci["country_iso3_code"].astype(str).str.upper()
    eci["year"] = pd.to_numeric(eci["year"], errors="coerce").astype("Int64")
    eci = eci[eci["year"].between(START_YEAR, END_YEAR)]
    eci = eci.drop_duplicates(["country_iso3_code", "year"])

    panel = eci.copy()
    panel = merge_indicator(panel, RAW_RENTS / "res_rent.dta", ["RES_RENT"], "")
    panel = merge_indicator(panel, RAW_GDPPC / "gdppc.dta", ["GDPPC"], "")
    panel = merge_indicator(panel, RAW_FIN / "fin.dta", ["FIN"], "")
    panel = merge_indicator(panel, RAW_RER / "rer.dta", ["RER"], "")

    humcap_wdi = clean_country_year(read_stata(RAW_HUMCAP_WDI / "humcap.dta"), ["HUMCAP"])
    humcap_wdi = humcap_wdi.drop(columns=["country"]).rename(
        columns={"HUMCAP": "HUMCAP_WDI"}
    )
    panel = panel.merge(
        humcap_wdi,
        on=["country_iso3_code", "year"],
        how="left",
        validate="one_to_one",
    )

    humcap_pwt = clean_country_year(read_stata(RAW_HUMCAP_PWT / "humcap_pwt.dta"), ["HUMCAP"])
    humcap_pwt = humcap_pwt.drop(columns=["country"]).rename(
        columns={"HUMCAP": "HUMCAP_PWT"}
    )
    panel = panel.merge(
        humcap_pwt,
        on=["country_iso3_code", "year"],
        how="left",
        validate="one_to_one",
    )

    panel = merge_indicator(panel, RAW_INNOV / "patents.dta", ["PATENTS"], "")

    fisc = read_stata(RAW_FISC / "fisc.dta").rename(columns={"iso3": "country_iso3_code"})
    fisc = clean_country_year(fisc, ["FISC"]).drop(columns=["country"])
    panel = panel.merge(
        fisc,
        on=["country_iso3_code", "year"],
        how="left",
        validate="one_to_one",
    )

    panel = panel.merge(
        build_institutions(),
        on=["country_iso3_code", "year"],
        how="left",
        validate="one_to_one",
    )

    panel = panel.merge(
        build_resource_profile(),
        on="country_iso3_code",
        how="left",
        validate="many_to_one",
    )

    panel["resource_dependent_sample"] = (
        panel["resource_dependent_sample"].fillna(0).astype("Int64")
    )

    write_outputs(panel)


if __name__ == "__main__":
    main()
