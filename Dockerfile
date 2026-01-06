FROM alpine:edge AS builder
RUN apk add --update crystal shards yaml-dev musl-dev make
RUN apk update && apk upgrade && apk add sqlite-static
WORKDIR /build/
ARG version
RUN git clone --branch ${version:-main} --depth 1 https://github.com/toddsundsted/ktistec .
RUN shards update && shards install --production
RUN crystal build src/ktistec/server.cr --static --no-debug --release

FROM node:latest AS nodebuilder
WORKDIR /build
COPY --from=builder /build /build
RUN npm install --save-dev webpack
RUN npm run build

FROM alpine:latest AS server
RUN apk --no-cache add tzdata
WORKDIR /app
COPY --from=nodebuilder /build/etc /app/etc
COPY --from=nodebuilder /build/public /app/public
COPY --from=nodebuilder /build/server /bin/server
RUN mkdir /db
RUN ln -s /app/public/uploads /uploads
ENV KTISTEC_DB=/db/ktistec.db
CMD ["/bin/server"]
VOLUME /db /uploads
EXPOSE 3000
