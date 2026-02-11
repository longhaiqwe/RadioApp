import urllib.request
import json
import os

def fetch_stations():
    url = "https://de1.api.radio-browser.info/json/stations/search"
    payload = {
        "countrycode": "CN",
        "order": "clickcount",
        "reverse": True,
        "limit": 100,
        "hidebroken": True
    }
    
    data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(url, data=data, method='POST')
    req.add_header('User-Agent', 'iOS-Radio-App/1.0')
    req.add_header('Content-Type', 'application/json')
    
    try:
        print(f"Fetching from {url}...")
        with urllib.request.urlopen(req, timeout=15) as response:
            if response.status != 200:
                print(f"HTTP Error: {response.status}")
                return
            
            response_data = response.read()
            stations = json.loads(response_data)
            print(f"Fetched {len(stations)} candidates.")
            
            # Filter logic
            music_tags = ["music", "pop", "hits", "rock", "jazz", "classical", "音乐", "流行", "top40", "dance", "rnb", "lofi"]
            filtered = []
            
            for station in stations:
                tags = station.get("tags", "").lower()
                if any(tag in tags for tag in music_tags):
                    filtered.append(station)
            
            print(f"Filtered to {len(filtered)} music stations.")
            
            # Take top 20
            top_20 = filtered[:20]
            
            # Save to file
            output_path = "RadioApp/Resources/preset_stations.json"
            
            # Ensure dir exists
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            
            with open(output_path, "w", encoding='utf-8') as f:
                json.dump(top_20, f, ensure_ascii=False, indent=2)
                
            print(f"Successfully saved {len(top_20)} stations to {output_path}")

    except Exception as e:
        print(f"Error fetching stations: {e}")

if __name__ == "__main__":
    fetch_stations()
