FROM ghcr.io/gleam-lang/gleam:v1.17.0-erlang-alpine AS build
WORKDIR /app
COPY . .
RUN gleam export erlang-shipment

# Same OTP major as the build image — BEAM files are not backwards compatible.
FROM erlang:29-alpine
# httpc verifies TLS against the OS trust store from OTP 26 on; without these
# the call to ffvbbeach.org fails handshake instead of returning the calendar.
RUN apk add --no-cache ca-certificates && update-ca-certificates
WORKDIR /app
COPY --from=build /app/build/erlang-shipment ./
EXPOSE 8000
ENTRYPOINT ["./entrypoint.sh", "run"]
