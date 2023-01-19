FROM docker.io/node:18-alpine AS node-builder
RUN mkdir /build
WORKDIR /build
COPY --chown=0:0 package.json package-lock.json /build/
RUN npm ci
COPY --chown=0:0 webpack.config.js ./
RUN mkdir src
COPY --chown=0:0 src/assets src/assets
RUN npm run build

FROM docker.io/crystallang/crystal:1.7.2-alpine AS crystal-builder
RUN apk update && apk upgrade && apk add sqlite-static
WORKDIR /build/
ARG version
COPY --chown=0:0 shard.yml shard.lock ./
RUN shards install --production
COPY --chown=0:0 etc etc
COPY --chown=0:0 src src
RUN crystal build src/ktistec/server.cr --progress --static --no-debug --release

FROM docker.io/library/alpine:latest AS server
RUN apk --no-cache add tzdata
WORKDIR /app
COPY --chown=0:0 etc /app/etc
COPY --chown=0:0 public /app/public
COPY --from=node-builder /build/public/dist /app/public/dist
COPY --from=crystal-builder /build/server /bin/server
RUN rm -rf /app/public/uploads && ln -sf /data/uploads /app/public/uploads
ENV KTISTEC_DB=/data/ktistec.db
CMD ["/bin/sh", "-c", "mkdir -p /data/uploads && exec /bin/server"]
VOLUME /data
EXPOSE 3000
