# syntax=docker/dockerfile:1
ARG NODE_IMAGE=node:20.18.1-alpine3.21

FROM ${NODE_IMAGE} AS builder
WORKDIR /app
COPY app/package.json app/package-lock.json* ./
RUN npm install --omit=dev
COPY app/src ./src

FROM ${NODE_IMAGE} AS runtime
ARG APP_VERSION=1.0.0
LABEL org.opencontainers.image.title="devops-task-app" \
      org.opencontainers.image.description="Small web service for the DevOps engineer assessment task" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.source="https://github.com/" \
      org.opencontainers.image.licenses="MIT"

ENV NODE_ENV=production \
    PORT=8080 \
    APP_VERSION=${APP_VERSION}

WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY app/package.json ./
COPY app/src ./src

# node:alpine already ships a non-root "node" user/group.
USER node

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:' + (process.env.PORT || 8080) + '/health', r => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"

CMD ["node", "src/index.js"]
