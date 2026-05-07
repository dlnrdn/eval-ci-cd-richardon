FROM node:20-alpine AS dependencies
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force

FROM node:20-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000
RUN addgroup -S quicknotes && adduser -S quicknotes -G quicknotes
COPY --from=dependencies /app/node_modules ./node_modules
COPY --chown=quicknotes:quicknotes package*.json ./
COPY --chown=quicknotes:quicknotes src ./src
USER quicknotes
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:' + (process.env.PORT || 3000) + '/health').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"
CMD ["npm", "start"]
