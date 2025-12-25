FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app

COPY flutter_web/ /app/
RUN rm -rf .dart_tool build .packages

# git safe.directory (dla roota)
RUN git config --global --add safe.directory /sdks/flutter

RUN flutter pub get
RUN flutter build web --release

FROM nginx:1.27-alpine
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80

