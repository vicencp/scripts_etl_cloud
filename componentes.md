# Diagrama

```

+-------+
| DCB   |
+-------+
    |
    |
    V
+---------------+
| API Telemetry |
+---------------+
    |
    |
    V
+------------+    +----------+    +-----------+
| S3 Datik   |--->| λ Datik  |--->| ES MASATS |-->+------------------+
+---------|--+    +----------+    +Λ-------Λ--+   | GRAFANA.datik.io |
          |                        |        \     +------------------+
          \_____________       'Excel data'  \
                        \          |          \
+------------+         +-V---------|+        +-\----------+
| EC2 Masats |         | EC2 Masats |        | EC2 Masats |
|   nagios   |-------->| CopyCat    |     ,--|   Docker   |
| (t3.small) |         | (t2.micro) |    /   |   Eurecat  |
+-|----------+         +------------+   /    | (t2.large) |
  |   |                     |          /     +------Λ-----+
  |   |                     |         /             |
  |   |                     V        /              |
  |   |            +------------+  ,/               |
  |   |            | S3 Masats  |</                 |
  ✉   |            +------------+                   |
  |   |                                             |
  |   \_____________________________________________/
  |
  GoogleChat, Email

```


## EC2

### Claves EC2

Para acceder a las máquinas EC2 del Cloud de Masats necesitamos
las claves SSH  correspondientes.

Name | Type | ID
-----+------+----
CloudMasats|rsa|key-0425359d027ecdaa9
nagios-masats|rsa|key-0b36355178d3709f5

`CloudMasats` se usa para la máquina que copia datos de S3 y limpia los
índices de Elasticsearch.

La misma clave también nos da acceso a la máquina de Eurecat.


### EC2 Nagios

Es la máquina que contiene el sistema [Nagios][Nagios] con
los scripts utilizados para monitorizar los procesos de las
otras dos máquinas. Cualquier duda contactar con
<a href="mailto:alegorburu@datik.es">alegorburu@datik.es</a>.

[Nagios]: https://www.nagios.org/

### EC2 CopyCat

### EC2 Docker Eurecat

En esta máquina se alojan los contenedores docker en los que
se ejecutan los algoritmos de Eurecat.


