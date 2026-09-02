FROM node:20-bookworm-slim

WORKDIR /app
COPY server.js ./

ENV NODE_ENV=production \
    PORT=8080
EXPOSE 8080

USER 65532:65532
CMD ["node", "server.js"]
