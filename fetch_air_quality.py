#!/usr/bin/env python3
"""
Fetch air quality data from Amazon Smart Air Quality Monitor via Alexa API.
Writes to ~/.config/aranet-bar/air-quality.json for the Aranet Bar menu bar app.

Setup:
  1. Run: cd ~/aranet-bar && node get-cookies.js  (log in to get cookies)
  2. Run: cd ~/aranet-bar && source venv/bin/activate && python3 fetch_air_quality.py

For continuous updates, add to crontab:
  */5 * * * * cd ~/aranet-bar && venv/bin/python3 fetch_air_quality.py
"""

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import requests

CONFIG_DIR = Path.home() / ".config" / "aranet-bar"
COOKIE_FILE = CONFIG_DIR / "alexa-cookies.txt"
OUTPUT_FILE = CONFIG_DIR / "air-quality.json"

ENTITY_ID = "ecb810a7-ec1e-4167-8ab5-0eb9bad41d9c"

# RangeController instance mapping for Amazon Smart Air Quality Monitor (Pear)
# Instance 4 = Humidity, 5 = VOC, 6 = PM2.5, 7 = CO, 8 = ?, 9 = AQ Score
INSTANCE_MAP = {
    "4": "humidity",
    "5": "voc",
    "6": "pm25",
    "7": "co",
    "9": "score",
}


def load_cookies():
    if not COOKIE_FILE.exists():
        print(f"No cookie file at {COOKIE_FILE}")
        print("Run: cd ~/aranet-bar && node get-cookies.js")
        sys.exit(1)

    lines = [
        line.strip()
        for line in COOKIE_FILE.read_text().splitlines()
        if line.strip() and not line.strip().startswith("#")
    ]
    if not lines:
        print(f"Cookie file is empty: {COOKIE_FILE}")
        sys.exit(1)

    return "; ".join(lines)


def fetch(cookies):
    s = requests.Session()
    s.headers["User-Agent"] = (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    )

    for part in cookies.split(";"):
        kv = part.strip().split("=", 1)
        if len(kv) == 2:
            s.cookies.set(kv[0], kv[1], domain=".amazon.com")

    # Step 1: get CSRF token
    r = s.get("https://alexa.amazon.com/api/language", timeout=15)
    csrf = s.cookies.get("csrf")
    if not csrf:
        print("Failed to get CSRF token — cookies may be expired")
        print("Run: cd ~/aranet-bar && node get-cookies.js")
        sys.exit(1)

    s.headers.update({
        "csrf": csrf,
        "Origin": "https://alexa.amazon.com",
        "Referer": "https://alexa.amazon.com/spa/index.html",
        "Content-Type": "application/json",
    })

    # Step 2: query device state
    payload = {"stateRequests": [{"entityId": ENTITY_ID, "entityType": "ENTITY"}]}
    r = s.post("https://alexa.amazon.com/api/phoenix/state", json=payload, timeout=15)

    if r.status_code != 200:
        print(f"API error: HTTP {r.status_code}")
        sys.exit(1)

    data = r.json()
    errors = data.get("errors", [])
    if errors:
        print(f"API error: {errors[0].get('message', errors)}")
        sys.exit(1)

    return data


def parse(data):
    result = {"device_name": "First Air Quality Monitor"}

    for state in data.get("deviceStates", []):
        for cap_str in state.get("capabilityStates", []):
            cap = json.loads(cap_str) if isinstance(cap_str, str) else cap_str
            ns = cap.get("namespace", "")
            instance = cap.get("instance", "")
            value = cap.get("value")
            ts = cap.get("timeOfSample", "")

            if ns == "Alexa.TemperatureSensor":
                result["temperature"] = value.get("value") if isinstance(value, dict) else value
                result["timestamp"] = ts

            elif ns == "Alexa.RangeController" and instance in INSTANCE_MAP:
                key = INSTANCE_MAP[instance]
                result[key] = value if not isinstance(value, dict) else value.get("value")
                if not result.get("timestamp"):
                    result["timestamp"] = ts

    if not result.get("timestamp"):
        result["timestamp"] = datetime.now(timezone.utc).isoformat()

    return result


def main():
    cookies = load_cookies()
    data = fetch(cookies)
    result = parse(data)

    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_FILE.write_text(json.dumps(result, indent=2))

    print(f"Temperature: {result.get('temperature')}°C")
    print(f"Humidity:    {result.get('humidity')}%")
    print(f"VOC:         {result.get('voc')} ppb")
    print(f"PM2.5:       {result.get('pm25')} µg/m³")
    print(f"CO:          {result.get('co')} ppm")
    print(f"AQ Score:    {result.get('score')}/100")
    print(f"Written to   {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
