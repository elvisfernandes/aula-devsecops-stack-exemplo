FROM node:20

WORKDIR /app
ADD . /app
RUN npm install
RUN npm run build

FROM nginx:1.18

COPY --from=0 /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
