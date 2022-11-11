FROM docker.io/crystallang/crystal:1.6.2-alpine AS builder
RUN apk update && apk upgrade && apk add sqlite-static
WORKDIR /build/
ARG version
RUN git clone --branch ${version:-dist} --depth 1 https://github.com/toddsundsted/ktistec .
RUN shards update && shards install --production
RUN crystal build src/ktistec/server.cr --static --no-debug --release

FROM docker.io/library/alpine:latest AS server
RUN apk --no-cache add tzdata
WORKDIR /app
COPY --from=builder /build/etc /app/etc
COPY --from=builder /build/public /app/public
COPY --from=builder /build/server /bin/server
RUN mkdir /db && ln -s /app/public/uploads /uploads
ENV KTISTEC_DB=/db/ktistec.db
CMD ["/bin/server"]
VOLUME /db /uploads
EXPOSE 3000
