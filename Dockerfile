FROM node:20-bookworm-slim


# OS deps: MySQL server + utilities used by setup_and_run.sh


WORKDIR /app
COPY create_table.sql create_user.sql server.sh  ./
COPY webgoat-2023.3.jar /
# App sources
COPY views/ ./views/
COPY public/ ./public/
COPY app.js ./
COPY package*.json ./
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    bash curl git lsof default-mysql-server default-jdk  vim \
 && rm -rf /var/lib/apt/lists/*

RUN chmod +x ./server.sh
RUN npm ci  
RUN npm install
RUN npm install mysql --save
# Install node deps




# Safety net: ensure mysql npm module exists (best fix is adding it to package.json)
RUN node -e "require.resolve('mysql')" >/dev/null 2>&1 



# Scripts + SQL



ENV CLEAN_FIRST=0
EXPOSE 8080 9090 3000




ENTRYPOINT ["/bin/bash","startup.sh"]

