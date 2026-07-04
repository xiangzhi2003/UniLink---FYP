# --- Build stage ---
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# .env is gitignored, so it doesn't exist in this build context — write it
# from Railway's build-time variables instead (Settings > Variables on the
# frontend service). The anon key is safe to bake into the client bundle,
# same as it would be in any Flutter build.
ARG SUPABASE_URL
ARG SUPABASE_ANON_KEY
ARG WEB_APP_URL
RUN echo "SUPABASE_URL=$SUPABASE_URL" > .env && \
    echo "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" >> .env && \
    echo "WEB_APP_URL=$WEB_APP_URL" >> .env

RUN flutter build web --release

# --- Runtime stage ---
FROM nginx:alpine

COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf.template /etc/nginx/templates/default.conf.template

# Railway assigns a dynamic $PORT; nginx's templating (built into the base
# image) substitutes it into the listen directive at container start.
ENV PORT=8080
EXPOSE 8080
