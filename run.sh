









IMAGE="mohajernoei/websecurity"
PORT="${1:-3000}"

# Ensure image is present / up to date
docker pull "${IMAGE}"


docker run --rm -it -p "${PORT}:3000" --volume .:/app/ "${IMAGE}"

