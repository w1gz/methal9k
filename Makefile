.PHONY: setup release test run docker-build-ngircd docker-build-bot docker-run-ngircd docker-run-bot docker-dev docker-stop
.DEFAULT_GOAL := run


### Bare metal
setup:
	mix local.hex --force
	mix local.rebar --force
	mix do deps.get --all

release: setup
	mix release

test: setup
	mix test

run: setup
	mix run --no-halt


### Docker part
docker-build-ngircd:
	docker build \
		-t methal9k.ngircd \
		-f docker_images/Dockerfile.ngircd .

docker-build-bot:
	docker build \
		-t methal9k.bot \
		-f docker_images/Dockerfile.bot .

docker-run-ngircd:
	docker run --rm -it -d \
		-p 6697\:6697 \
		--name methal9k.ngircd \
		methal9k.ngircd

docker-run-bot:
	docker run --rm -it -d \
		-v $$(pwd):/app -w /app \
		-e "MIX_ENV=prod COOKIE=ChangeMeOrElse" \
		--name methal9k.bot \
		$(opts) \
		methal9k.bot

docker-dev: docker-build-ngircd docker-build-bot
	${MAKE} docker-run-ngircd
	${MAKE} docker-run-bot opts="--link methal9k.ngircd"

docker-stop:
	@docker stop methal9k.ngircd | true
	@docker stop methal9k.bot | true
