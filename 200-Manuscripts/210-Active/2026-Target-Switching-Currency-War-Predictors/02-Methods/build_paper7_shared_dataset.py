from __future__ import annotations

from pathlib import Path

import pandas as pd


ROOT = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")
P1 = ROOT / "300-Projects/310-Active-Papers/2026-Currency-Wars-Gold-Asymmetry/03-Results/paper1_gold_currency_wars_dataset.csv"
P2 = ROOT / "300-Projects/310-Active-Papers/2026-Regime-Volatility-Gold-Forecasting/03-Results/paper2_gold_regime_volatility_dataset.csv"
P5 = ROOT / "300-Projects/310-Active-Papers/2026-Gold-Crypto-Safe-Haven-Competition/03-Results/paper5_gold_crypto_dataset_v1.csv"
OUT_CSV = ROOT / "300-Projects/310-Active-Papers/2026-Target-Switching-Currency-War-Predictors/03-Results/paper7_shared_target_dataset.csv"
OUT_NOTE = ROOT / "300-Projects/310-Active-Papers/2026-Target-Switching-Currency-War-Predictors/03-Results/paper7_shared_target_dataset.source_note.md"


def main() -> None:
    p1 = pd.read_csv(P1, parse_dates=["DATE"])
    p2 = pd.read_csv(P2, parse_dates=["DATE"])
    p5 = pd.read_csv(P5, parse_dates=["DATE"])

    base = p1[
        [
            "DATE",
            "dxy_return",
            "usdjpy_return",
            "usdchf_return",
            "oil_return",
            "vix_change",
            "epu_us",
            "currency_war_flag",
            "gold_return",
        ]
    ].copy()

    vol = p2[["DATE", "gold_rv_proxy", "gold_abs_proxy", "regime_label"]].copy()
    crypto = p5[["DATE", "btc_return", "gold_btc_spread_return", "crisis_flag"]].copy()

    merged = base.merge(vol, on="DATE", how="inner").merge(crypto, on="DATE", how="inner")
    merged = merged.sort_values("DATE").dropna().reset_index(drop=True)
    merged.to_csv(OUT_CSV, index=False)

    OUT_NOTE.write_text(
        "\n".join(
            [
                "# Source Note",
                "- Predictors sourced from Paper 1 shared macro-financial core",
                "- Gold volatility targets sourced from Paper 2",
                "- BTC and spread targets sourced from Paper 5",
                "- This dataset keeps one common predictor universe and multiple dependent variables",
            ]
        )
        + "\n",
        encoding="utf-8",
    )

    print(f"Saved dataset: {OUT_CSV}")
    print(f"Saved note: {OUT_NOTE}")


if __name__ == "__main__":
    main()
