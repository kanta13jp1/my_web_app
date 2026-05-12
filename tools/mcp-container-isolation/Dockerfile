FROM python:3.12-alpine

RUN addgroup -S mcp && adduser -S -G mcp -h /app mcp
WORKDIR /app

COPY mcp_stdio_ping.py /app/mcp_stdio_ping.py
RUN chmod 0555 /app/mcp_stdio_ping.py

USER mcp
ENTRYPOINT ["python", "/app/mcp_stdio_ping.py"]
