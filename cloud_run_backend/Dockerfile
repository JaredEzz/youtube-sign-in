# Use the official Dart image
FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart compile exe bin/server.dart -o bin/server

# Build minimal serving image
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/server
COPY --from=build /app/dex-tags-1e80efd082ac.json /app/dex-tags-1e80efd082ac.json

# Cloud Run expects the app to listen on port 8080
ENV PORT=8080
CMD ["/app/bin/server"]
