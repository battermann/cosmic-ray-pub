# Build Stage
FROM node:13.4.0-buster as build
USER node
ENV NPM_CONFIG_PREFIX=/home/node/.npm-global
ENV PATH=$PATH:/home/node/.npm-global/bin
ARG REDIS_URL
ARG DB_HOST
ARG DB_NAME
ARG DB_USER
ARG DB_PASS
ENV REDIS_URL=$REDIS_URL
ENV DB_HOST=$DB_HOST
ENV DB_NAME=$DB_NAME
ENV DB_USER=$DB_USER
ENV DB_PASS=$DB_PASS
WORKDIR /app
COPY ./src ./src
COPY ./index.js ./index.js
COPY ./package.json ./package.json
COPY ./packages.dhall ./packages.dhall  
COPY ./spago.dhall ./spago.dhall
COPY ./package.json ./package.json
COPY ./package-lock.json ./package-lock.json
USER root
RUN apt-get update && apt-get install libncurses5 -y
RUN npm install --unsafe-perm=true
RUN npx spago build
CMD node .
