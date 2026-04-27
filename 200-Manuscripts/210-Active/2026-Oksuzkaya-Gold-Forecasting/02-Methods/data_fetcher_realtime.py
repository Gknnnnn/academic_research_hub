import yfinance as yf
import pandas as pd
import time
import os
from datetime import datetime

# Configuration for High-Frequency (Anlık) Research Data
# We keep this as an extension layer, not as the main paper backbone.
SYMBOLS = {
    "XAU_FUT": "GC=F",      # Gold futures
    "XAU_SPOT": "XAUUSD=X", # Spot-like gold proxy on Yahoo Finance
    "USDJPY": "JPY=X",      # USD/JPY
    "USDCHF": "CHF=X",      # USD/CHF
    "VIX": "^VIX",          # Volatility index
    "SP500": "^GSPC"        # Equity benchmark
}

OUTPUT_FILE = "gold_realtime_sampler.csv"

def fetch_realtime_data():
    """
    Fetches 1-minute interval data for the last 1 day to simulate "Anlık" (real-time) forecasting inputs.
    In a production loop, this would sample the latest tick.
    """
    print(f"🚀 Initializing High-Frequency Data Sampler at {datetime.now()}...")
    
    all_data = []
    for name, ticker in SYMBOLS.items():
        try:
            print(f"🔍 Sampling {name} ({ticker})...")
            # Fetch 1m data for the last day
            data = yf.download(ticker, period="1d", interval="1m", progress=False)
            if not data.empty:
                # We take the 'Close' price
                latest_price = data['Close'].iloc[-1]
                timestamp = data.index[-1]
                all_data.append({
                    "Timestamp": timestamp,
                    "Variable": name,
                    "Price": float(latest_price)
                })
        except Exception as e:
            print(f"⚠️ Error fetching {name}: {e}")

    if all_data:
        df = pd.DataFrame(all_data)
        # Pivot to wider format for Forecaster
        df_pivot = df.pivot(index="Timestamp", columns="Variable", values="Price")
        
        # Save/Append to buffer
        if os.path.exists(OUTPUT_FILE):
             df_pivot.to_csv(OUTPUT_FILE, mode='a', header=False)
        else:
             df_pivot.to_csv(OUTPUT_FILE)
        
        print(f"✅ Data Buffered in {OUTPUT_FILE}. Current Gold Price: {df_pivot.get('XAU', ['N/A']).iloc[0]}")
        return df_pivot
    return None

if __name__ == "__main__":
    # Simulate a loop for "Anlık" data visibility
    for i in range(3):
        fetch_realtime_data()
        if i < 2:
            print("⏳ Waiting 60s for next tick...")
            time.sleep(60)
