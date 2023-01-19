FROM docker.io/crystallang/crystal:1.2.2-alpine AS builder
RUN apk update && apk upgrade && apk add sqlite-static
WORKDIR /build/
ARG version
COPY --chown=0.0 shard.yml shard.lock .
RUN shards install --production
COPY --chown=0:0 . .
RUN crystal build src/ktistec/server.cr --static --no-debug --release

FROM alpine:latest AS server
RUN apk --no-cache add tzdata
WORKDIR /app
COPY --from=builder /build/etc /app/etc
COPY --from=builder /build/public /app/public
COPY --from=builder /build/server /bin/server
RUN mkdir /db
RUN ln -s /app/public/uploads /uploads
ENV KTISTEC_DB=/db/ktistec.db
CMD ["/bin/server"]
VOLUME /db /uploads
EXPOSE 3000
