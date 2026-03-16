# AranetBar

A macOS menu bar app that displays real-time air quality data from two sources:

- **Aranet4** — CO2, temperature, humidity, pressure via Bluetooth
- **Amazon Smart Air Quality Monitor** — VOC and PM2.5 via Alexa API

![menu bar](https://img.shields.io/badge/macOS-14%2B-blue)

## Menu Bar

The menu bar shows all readings at a glance with color-coded values (green/orange/red):

```
● 850 ppm │ 1voc 1.0pm
```

Click to expand the popover with detailed readings, device status, and history.

## Setup

### Prerequisites

- macOS 14+
- Swift 5.9+
- An [Aranet4](https://aranet.com/products/aranet4/) sensor (Bluetooth)
- An [Amazon Smart Air Quality Monitor](https://www.amazon.com/dp/B09DK9XNLQ) (optional)

### Build & Run

```bash
./build.sh
open build/AranetBar.app

# To install permanently:
cp -R build/AranetBar.app /Applications/
```

### Amazon Air Quality Monitor Setup

1. Install `alexa-cookie2`:
   ```bash
   npm install -g alexa-cookie2
   ```

2. Get your Alexa cookies:
   ```bash
   node get-cookies.js
   ```
   Open http://127.0.0.1:3456/ in your browser and log in with your Amazon account.
   Cookies are saved to `~/.config/aranet-bar/alexa-cookies.txt`.

3. Set up the Python fetcher:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install requests
   python3 fetch_air_quality.py
   ```

4. Add a cron job to fetch every 5 minutes:
   ```bash
   (crontab -l 2>/dev/null; echo "*/5 * * * * cd ~/aranet-bar && venv/bin/python3 fetch_air_quality.py >> /tmp/aranet-aq.log 2>&1") | crontab -
   ```

## How It Works

```
┌──────────────┐     Bluetooth      ┌────────────────┐
│   Aranet4    │ ──────────────────▶ │                │
│  (CO2, temp, │                    │   AranetBar    │
│   humidity)  │                    │  (menu bar)    │
└──────────────┘                    │                │
                                    └───────┬────────┘
┌──────────────┐    Alexa API       ┌───────┴────────┐
│ Amazon AQ    │ ──────────────────▶ │ fetch_air_     │
│  Monitor     │  (cron, every 5m)  │ quality.py     │
│ (VOC, PM2.5) │                    │  ↓ JSON file   │
└──────────────┘                    └────────────────┘
```

- **Aranet4**: Connected via CoreBluetooth. Polls every 60 seconds. Auto-reconnects.
- **Amazon AQ Monitor**: A Python script fetches VOC/PM2.5 from the Alexa API and writes to `~/.config/aranet-bar/air-quality.json`. The Swift app reads this file every 30 seconds.

## Files

| File | Description |
|------|-------------|
| `Sources/AranetBar/AranetBarApp.swift` | App entry point, menu bar icon rendering |
| `Sources/AranetBar/AranetService.swift` | Aranet4 Bluetooth connection and data parsing |
| `Sources/AranetBar/AlexaService.swift` | Reads Amazon AQ data from local JSON file |
| `Sources/AranetBar/PopoverView.swift` | Popover UI with all sensor readings |
| `fetch_air_quality.py` | Fetches VOC/PM2.5 from Alexa API |
| `get-cookies.js` | Proxies Amazon login to capture Alexa cookies |
| `build.sh` | Builds the .app bundle |

## Color Thresholds

| Metric | Green | Orange | Red |
|--------|-------|--------|-----|
| CO2 | < 800 ppm | 800–1400 ppm | > 1400 ppm |
| VOC | ≤ 300 ppb | 300–1000 ppb | > 1000 ppb |
| PM2.5 | ≤ 12 µg/m³ | 12–35 µg/m³ | > 35 µg/m³ |
