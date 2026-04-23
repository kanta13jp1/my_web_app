import urllib.request
import re

url = 'https://docs.google.com/spreadsheets/d/1WZlHr6YWG8ZbT9r-wXtYPEdPT5E4b47PSpNSNl8A1MM/htmlview'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    html = urllib.request.urlopen(req).read().decode('utf-8')
    matches = re.findall(r'"name":"([^"]+)","gid":"(\d+)"', html)
    print("Sheets:", matches)
except Exception as e:
    print(e)
