# Build stage
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN apk add --no-cache --upgrade \
    c-ares=1.34.5-r0 \
    libexpat=2.7.0-r0 \
    libxml2=2.13.4-r5 \
    libxslt=1.1.42-r2 \
    xz-libs=5.6.3-r1

RUN npm ci
COPY . .
RUN npm run build

# Production stage
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
RUN apk add --no-cache --upgrade \
    c-ares=1.34.5-r0 \
    libexpat=2.7.0-r0 \
    libxml2=2.13.4-r5 \
    libxslt=1.1.42-r2 \
    xz-libs=5.6.3-r1
# Add nginx configuration if needed
# COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]