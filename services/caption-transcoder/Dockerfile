# caption-transcoder: ffmpeg burn-in service for X-share presenter videos.
# ffmpeg + Noto Sans CJK JP (so Japanese captions render, not tofu).
FROM node:20-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ffmpeg \
      fonts-noto-cjk \
      ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY server.js ./
ENV PORT=8080
EXPOSE 8080
CMD ["node", "server.js"]
