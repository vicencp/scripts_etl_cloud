Este repo contiene los scripts usados para tareas ETL de masats,
están como binario en ~/bin en la máquina i-0083a804361ed511b
(nombre `CopyCat書き写す猫`) de AWS.

En cierto modo todo es ETL 🙂.

En [componentes.md](componentes.md) se explica mediante un diagrama donde esta desplegado cada componente.

Los scripts en la carpeta `./bin` están escritos
principalmente en `sh` aunque es posbile que haya algo de `bash`),
`jq` para procesar JSON, `curl` para peticiones HTTP,
`python` y `go`.

## crontab

Los `scripts` se usan como servicio CRON. Su especificación
está en el fichero `masats.cron`.

## REQUISITOS de SCRIPTS

    python3
    sh
    parallel
    jq
    curl
    golang
    awscli
    awk
    sed

### INSTALACIÓN

    sudo apt install python3 dash parallel golang mawk sed

### COMPILACION SCRIPTS en GO

Primero instalar dependencias de aws (S2)

    go get "github.com/aws/aws-sdk-go/aws"
    go get "github.com/aws/aws-sdk-go/aws/session"
    go get "github.com/aws/aws-sdk-go/service/s3"

Y luego

    go build s3_many_copy.go

## Eventos iPanel

Hay una serie de scripts que se usan para crear eventos
en iPanel.

También hay un Dockerfile con un entorno para lanzarlo y
un K8s yaml para desplegarlo en un cluster de Kubernetes.

Los scripts son:

    bin/alarmas_masats.sh
    bin/alarms_ia.sh
    bin/crear-eventos-ipanel.sh

El Dockerfile

    bin/Dockerfile-masats-eventos

que podemos agregar al repositorio de Datik mediante `make`

    cd bin && make docker

Y que luego desplegamos en k8s con

    kubectl apply -f cronjob-k8s-masats-eventos.yaml

## Plugin GRAFANA

También está presente el plugin de grafana para poder
visualizar las curvas de consumo tal y como las guardamos en Elasticsearch.

### REQUISITOS

    grafana
    nodejs
    yarn

### Compilación del plugin

Desarrollo

    yarn dev

Producción

    yarn build


## TAREAS MASATS

Hay una serie de tareas cron para sincronizar los datos del S3 de Datik
al S3 de Masats, limpiar el Elasticsearch de Masats y generar los índices
de los percentiles en elasticsearch.


```cron
# m h     dom mon dow command
   0 */12  *   *   *  sync_consolidated.sh  >/dev/null 2>&1
  30  *    *   *   *  time sync_s3_data.sh  > ~/log/sync_s3_data.log  2>&1
  13 */6   *   *   *  forcemerge.sh >  ~/log/forcemerge.log 2>&1
  55  1    *   *   *  deletebyquery.sh > ~/log/last_delete_by_query.log 2>&1
 */2  *    *   *   *  masats_limits_query.sh > ~/log/last_limits_query.log 2>&1
  12  *    *   *   *  rm -f /home/ubuntu/percentiles_conf.json

```

Además, en el Kubernetes de Datik hay un proceso generando eventos
y enviando los JSON correspondientes al SQS en el entorno producción.

### Sincroniazción de datos

Los scripts correspondientes son

```
   0 */12  *   *   *  sync_consolidated.sh  >/dev/null 2>&1
  30  *    *   *   *  time sync_s3_data.sh  > ~/log/sync_s3_data.log  2>&1
```

### Limpieza de elasticsearch

Los scripts correspondientes son

```
  13 */6   *   *   *  forcemerge.sh >  ~/log/forcemerge.log 2>&1
  55  1    *   *   *  deletebyquery.sh > ~/log/last_delete_by_query.log 2>&1
```

Forcemerge es para forzar el borrado de documentos JSON.
En Elasticsearch el comando `delete` no borra, lo que hace es marcar
como "borrados" y no mostrarlos como resultado en las consultas.

No sé cómo hacer esto de forma eficiente con el Elasticsearch que nos
da Amazon, dado que es "managed" y no podemos cambiar todos los knobs
que nos gustaría.

### Percentiles

Los scripts correspondientes son

```
 */2  *    *   *   *  masats_limits_query.sh > ~/log/last_limits_query.log 2>&1
  12  *    *   *   *  rm -f /home/ubuntu/percentiles_conf.json
```

El segundo fuerza el refresco del cálculo cada 12 horas.



### Alarmas por SQS

La solución de Masats —al pasar por `iPanel`— necesita que los eventos
(por custom que sean) pasen por los procesos de las tripas de iPanel.
A efectos prácticos, requiere tener un proceso que envíe los eventos
generados por la IA de Eurecat a la SQS de eventos de producción.

```Docker
FROM git.datik.io:5005/ipanel-backend/ms_reports/report_framework:lite
WORKDIR /root/

COPY \
    alarmas_masats.sh \
    alarms_ia.sh \
    crear-eventos-ipanel.sh \
    /root/

COPY publish2sns.py /root/bin/

CMD /root/crear-eventos-ipanel.sh
```


### Tareas TunnelAWS

También hay otras tareas que se realizan en la máquina de los
túneles de amazon.



### Sincronización de xml

Ejemplo para los buses de Masats Singapur en
`/home/ubuntu/update_MASATS_thingies/MS_updates/`.

Añado el script que lanza las tareas de forma asíncrona a continuación:

```sh
#!/bin/sh

list_remaining() {
	echo "$(date -Is)": remaining:
	cat remaining | sed -f port2bus.sed
	echo "$(date -Is)": done ports:
	grep -v -f remaining pMS | sed -f port2bus.sed
}

while [ "$(wc -l < remaining)" -gt 0 ]; do
	for p in $(netstat -nltp4 | grep  -f remaining -o); do
		echo "$p" | sed -f port2bus.sed
		if (
			set -e
			sshpass -p datikinstaller ssh -C -o ConnectTimeout=10 -P $p \
				-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
				root@localhost rm -f /opt/datik/dcb_x/etc/p?_reader_config_jema.xml

			sshpass -p datikinstaller scp -C -o ConnectTimeout=10 -P $p \
				-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
				p1_reader_config.xml p2_reader_config.xml \
				p3_reader_config.xml \
				root@localhost:/opt/datik/dcb_x/etc/

			sshpass -p datikinstaller ssh -o ConnectTimeout=10 -p $p \
				-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
				root@localhost 'ls -lh /opt/datik/dcb_x/etc/p*_reader_config.xml'

			sshpass -p datikinstaller ssh -o ConnectTimeout=10 -p $p \
				-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
				root@localhost 'reboot'
		); then
			echo "$(date -Is)" yay, it worked for $p
			sed -i '/^'$p'$/d' remaining # remove from the remaining list
		fi
	done
	list_remaining
	sleep 30
done
```

### Extracción de tramas CAN en crudo

Igual que para actualizar los xml, también podemos programar
la captura de tramas CAN en crudo, normalmente suelen pedir de Masats
para comprobar si lo que están publicando tiene o no algún fallo.

Un problema que no se ha conseguido aclarar es que en las p1 de Singapur
hay muchas maniobras en las que no llegan todas las muestras de consumos.

```sh
#!/bin/sh

start=$(date +%s)

while [ $(date +%s) -lt $((start+72*60*60)) ]; do
	for k in $(cat portsMS); do
		p="${k%/*}"; b="${k#*/}";
		logfile="$log_$b.csv.gz"
		if ! lsof "$logfile" >/dev/null 2>&1; then
			sshpass -p datikinstaller ssh -C -o ConnectTimeout=10 -p "$p" \
				-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
				root@localhost \
				candump -L -n 10000 -T 3000 \
					can1,18FCA100:DFFFF00 \
					can1,18FCA200:DFFFF00 \
					can1,18FCA300:DFFFF00 \
					can1,18FCB100:DFFFF00 \
					can1,18FCC100:DFFFF00 \
					can1,18FCC200:DFFFF00 \
					can1,18FCC300:DFFFF00 \
					can1,18FCD100:DFFFF00 \
					can1,18FCE100:DFFFF00 \
				| gzip \
				>> "$logfile" &
			echo "$(date -Is) - scheduled raw can frames collection on $b"
		else
			echo "$(date -Is) - already working on $b"
		fi
	done
	sleep 60
done
```


### WHO to call

### Elasticsearch

<hrumayor@datik.es>, <aagundez@datik.es>, <mzurutuza@datik.es>.

### Tunnel AWS

<cjandula@datik.es>, <kkwiat@datik.es>, <alegorburu@datik.es>. 

### Eventos

<hrumayor@datik.es>, <ielgarresta@datik.es>.

### Grafana

Despliegue: <aolano@datik.es>.

Dashboards: <https://grafana.com/docs/grafana/latest/> 💪🏿.
