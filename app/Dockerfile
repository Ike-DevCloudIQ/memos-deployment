# Stage 1: Build frontend assets with pnpm
FROM node:24-alpine AS web-builder
WORKDIR /frontend-build/web
RUN corepack enable && corepack prepare pnpm@11.0.1 --activate

COPY web/package.json web/pnpm-lock.yaml web/pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile

COPY web/ ./
RUN pnpm release

# Stage 2: Build backend binary
FROM golang:1.26.2-alpine AS backend-builder
WORKDIR /backend-build
RUN apk add --no-cache git ca-certificates

COPY go.mod go.sum ./
RUN go mod download

COPY . ./
COPY --from=web-builder /frontend-build/server/router/frontend/dist ./server/router/frontend/dist
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -tags netgo,osusergo -o memos ./cmd/memos

# Stage 3: Runtime image
FROM alpine:3.21
RUN apk add --no-cache ca-certificates tzdata su-exec && \
    addgroup -g 10001 -S memos && \
    adduser -u 10001 -S -G memos -h /var/opt/memos memos && \
    mkdir -p /var/opt/memos && \
    chown -R memos:memos /var/opt/memos

WORKDIR /var/opt/memos
COPY --from=backend-builder /backend-build/memos /usr/local/bin/memos

USER memos
EXPOSE 5230
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:5230/api/v1/ping || exit 1

CMD ["/usr/local/bin/memos"]
