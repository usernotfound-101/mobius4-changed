FROM node:22-bookworm-slim

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY . .
RUN mkdir -p logs

EXPOSE 7603 7582

CMD ["node", "mobius4.js"]
