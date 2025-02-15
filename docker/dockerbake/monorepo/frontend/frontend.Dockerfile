# Define the argument with a default value
ARG NODE_VERSION=20
FROM node:${NODE_VERSION}

# Set working directory
WORKDIR /app
COPY . .
RUN npm install
CMD ["node", "server.js"]
