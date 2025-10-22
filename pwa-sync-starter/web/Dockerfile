
FROM node:20-alpine
WORKDIR /usr/src/app

# Install dependencies
COPY package.json ./
RUN npm install

# Copy source code
COPY . .

# Build the app
RUN npm run build

EXPOSE 4173
CMD [ "npm", "run", "preview", "--", "--host", "0.0.0.0" ]
