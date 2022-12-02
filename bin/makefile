
NAME=ingenieria/masats/etl-scripts
SERVER=git.datik.io:5005

docker: alarmas_masats.sh \
        alarms_ia.sh \
        crear-eventos-ipanel.sh
	docker build -f Dockerfile-masats-eventos -t $(SERVER)/$(NAME):dev .
	docker push $(SERVER)/$(NAME):dev

