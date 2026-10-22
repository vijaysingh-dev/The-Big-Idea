**Up:** [[00 - Index (Backend)]] | **Prev:** [[Assets.6 - Rapid Fire Question Bank]]

---

## 1. Images

``` bash
# List local images
docker images

# Pull an image
docker pull nginx

# Remove an image
docker rmi nginx

# Remove unused images
docker image prune
```

## 2. Containers

``` bash
# List running containers
docker ps

# List ALL containers (including stopped)
docker ps -a

# Create and start a container
docker run nginx

# Run in background
docker run -d nginx

# Give the container a name
docker run -d --name my-nginx nginx

# Run with port mapping
docker run -d --name my-nginx -p 8080:80 nginx
```

## 3. Start / Stop / Restart

``` bash
# Start a stopped container
docker start my-nginx

# Stop a running container
docker stop my-nginx

# Restart a container
docker restart my-nginx

# Kill immediately
docker kill my-nginx
```

### Important distinction

``` text
docker stop     → gracefully stop
docker kill     → immediately terminate
docker restart  → stop + start
```

You can also use the container ID:

``` bash
docker restart 3f82a1c9
```

## 4. Execute Commands Inside a Container

``` bash
# Open a shell
docker exec -it my-nginx bash

# If bash doesn't exist
docker exec -it my-nginx sh

# Execute a single command
docker exec my-nginx ls

# Execute as root
docker exec -it -u root my-nginx bash
```

## 5. Logs

``` bash
# Show logs
docker logs my-nginx

# Follow logs
docker logs -f my-nginx

# Last 100 lines
docker logs --tail 100 my-nginx

# Logs + follow
docker logs -f --tail 100 my-nginx
```

## 6. Inspect / Information

``` bash
# Container details
docker inspect my-nginx

# Resource usage
docker stats

# Container processes
docker top my-nginx
```

## 7. Remove Containers

``` bash
# Remove stopped container
docker rm my-nginx

# Force remove running container
docker rm -f my-nginx

# Remove all stopped containers
docker container prune
```

## 8. Copy Files

``` bash
# Host → container
docker cp ./config.json my-nginx:/app/config.json

# Container → host
docker cp my-nginx:/app/log.txt ./log.txt
```

## 9. Ports / Networking

``` bash
# Show port mappings
docker port my-nginx

# List networks
docker network ls

# Inspect a network
docker network inspect bridge
```

## 10. Environment Variables

``` bash
docker run -d \
  --name my-app \
  -e DATABASE_URL="postgresql://localhost/db" \
  my-app:latest
```

See environment variables:

``` bash
docker inspect my-app
```

## 11. Build an Image

``` bash
# Build using Dockerfile in current directory
docker build -t my-app .

# Build with a specific Dockerfile
docker build -f Dockerfile.dev -t my-app:dev .
```

Run it:

``` bash
docker run -d --name my-app my-app:latest
```

## 12. Docker Compose

For multi-container applications:

``` bash
# Start services
docker compose up

# Start in background
docker compose up -d

# Stop services
docker compose down

# Restart services
docker compose restart

# Restart a specific service
docker compose restart backend

# Rebuild and start
docker compose up -d --build

# View logs
docker compose logs

# Follow logs
docker compose logs -f backend

# List services
docker compose ps
```

## Most Important Commands to Remember

``` text
IMAGE                         CONTAINER

docker pull                  docker run
docker images                docker ps
docker build                 docker start
docker rmi                   docker stop
                              docker restart
                              docker exec
                              docker logs
                              docker inspect
                              docker rm
```

## Common Troubleshooting Workflow

For a container that is behaving unexpectedly:

``` bash
docker ps -a
docker logs my-app
docker restart my-app
docker exec -it my-app bash
```

With Docker Compose:

``` bash
docker compose ps
docker compose logs -f backend
docker compose restart backend
docker compose up -d --build
```

---

**Next:** [[Vim]]
