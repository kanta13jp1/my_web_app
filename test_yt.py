import urllib.request
import re
import json
import sys

def get_yt_stats(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
    try:
        html = urllib.request.urlopen(req).read().decode('utf-8')
        
        # Extract ytInitialData
        match = re.search(r'var ytInitialData = (\{.*?\});</script>', html)
        if not match:
            return "No ytInitialData found"
        
        data = json.loads(match.group(1))
        
        # Try to find view count, likes, comments (simplified parsing)
        # This can be complex depending on the video/shorts
        return json.dumps({"status": "Success, ytInitialData loaded", "length": len(html)})
    except Exception as e:
        return str(e)

if __name__ == "__main__":
    print(get_yt_stats("https://www.youtube.com/watch?v=si7cCPi6nqY"))
