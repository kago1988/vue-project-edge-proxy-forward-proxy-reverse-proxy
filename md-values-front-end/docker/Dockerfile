# Frontend container: Angular dev server + Nginx forward proxy
FROM node:20-alpine

# Install Nginx + basic tools
RUN apk add --no-cache nginx bash

WORKDIR /usr/src/app

# 1) Angular app
# Build context will be the medicalvalues-front-end directory's parent.
# So "front-end" and "forward-proxy" exist at build context root.
COPY front-end/package*.json ./front-end/
WORKDIR /usr/src/app/front-end
RUN npm ci

# Copy Angular source
COPY front-end ./

# 2) Forward proxy config
WORKDIR /usr/src/app
COPY forward-proxy ./forward-proxy
RUN mkdir -p forward-proxy/logs

# 3) Start script
COPY docker/start-frontend.sh /usr/local/bin/start-frontend.sh
RUN chmod +x /usr/local/bin/start-frontend.sh

# Expose Angular dev server + forward proxy ports
EXPOSE 4200 3128

CMD ["start-frontend.sh"]
