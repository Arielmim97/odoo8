# Odoo 8 con Docker Compose

Levanta Odoo 8 para desarrollo con un comando. Misma idea que [odoo-15-docker-compose](https://github.com/minhng92/odoo-15-docker-compose): Postgres, carpeta de addons, config montada y un script para varias instancias.

Odoo 8 no puede usar las imágenes de Odoo 15.

| | Odoo 15 (referencia) | Este repo |
| --- | --- | --- |
| App | `odoo:15` | `odoo:8.0` (solo `linux/amd64`, imagen de 2017) |
| Base de datos | `postgres:14` | `postgres:9.6` |
| Config | `etc/odoo.conf` | `etc/openerp-server.conf` |
| Proceso | `odoo` | `openerp-server` |
| Puerto web / chat | `10015` / `20015` | `10008` / `20008` |

`postgres:9.6` es la última serie con la que Odoo 8 arranca sin parches. PostgreSQL 10 y posteriores rompen el servidor 8. En Mac con Apple Silicon, Docker tiene que emular `linux/amd64` para `odoo:8.0` (activa Rosetta en Docker Desktop).

Instala [Docker](https://docs.docker.com/get-docker/) y Docker Compose, luego:

```bash
git clone --branch odoo8 https://github.com/Arielmim97/odoo8.git
cd odoo8
mkdir -p postgresql
chmod 777 addons etc postgresql
chmod +x entrypoint.sh
docker compose up -d
```

Abre `http://localhost:10008`. Contraseña maestra del gestor de bases: `admin` (cámbiala en `etc/openerp-server.conf`). Usuario y clave de Postgres: `odoo` / `odoo`.

## Varias instancias

```bash
curl -s https://raw.githubusercontent.com/Arielmim97/odoo8/odoo8/run.sh | bash -s odoo-one 10008 20008
```

```bash
curl -s https://raw.githubusercontent.com/Arielmim97/odoo8/odoo8/run.sh | bash -s odoo-two 11008 21008
```

* Primer argumento: carpeta de despliegue
* Segundo: puerto HTTP de Odoo
* Tercero: puerto de live chat

## Uso

```bash
docker compose up -d    # arrancar
docker compose restart  # reiniciar
docker compose down     # parar
docker compose logs -f odoo8
```

`docker-compose` (con guion) también sirve si es el binario que tienes instalado.

Si el contenedor no puede escribir en los volúmenes:

```bash
chmod 777 addons etc postgresql
```

En Linux, si vas a correr varias instancias, sube el límite de inotify (en macOS no aplica):

```bash
if grep -qF "fs.inotify.max_user_watches" /etc/sysctl.conf; then echo $(grep -F "fs.inotify.max_user_watches" /etc/sysctl.conf); else echo "fs.inotify.max_user_watches = 524288" | sudo tee -a /etc/sysctl.conf; fi
sudo sysctl -p
```

## Addons

Pon los módulos propios en `addons/`. El contenedor los ve en `/mnt/extra-addons`, que ya está en `addons_path`.

## Configuración y log

* Config: `etc/openerp-server.conf` (Odoo 8 no usa `odoo.conf`; la imagen lee `OPENERP_SERVER=/etc/odoo/openerp-server.conf`)
* Log: `etc/odoo-server.log`
* Filestore y sesiones quedan dentro de `etc/` porque `data_dir = /etc/odoo`
* Contraseña maestra: `admin_passwd` en `etc/openerp-server.conf`

## Live chat

El puerto `20008` del host apunta al `8072` del contenedor. Con `workers = 0` (el valor de esta config) Odoo 8 atiende todo por el `8069` y no abre el `8072`. Para separar el longpolling, sube `workers` en `etc/openerp-server.conf` y reinicia.

Nginx en producción:

```nginx
location /longpolling/ {
    proxy_pass http://127.0.0.1:20008/longpolling/;
}
```

## Paquetes Python extra

`etc/requirements.txt` es Python 2.7. La imagen no trae `pip3` y `apt-get` dentro del contenedor falla: Debian Jessie ya no tiene mirrors. Descomenta un paquete solo si `pip` existe dentro de la imagen.
