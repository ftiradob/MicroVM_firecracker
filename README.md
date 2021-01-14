# MICRO VM CON FIRECRACKER

## Índice

### [1. Introducción](https://github.com/ftiradob/MicroVM_firecracker#1-introducci%C3%B3n-1)
### [2. Conceptos previos](https://github.com/ftiradob/MicroVM_firecracker#2-conceptos-previos-1)
### [3. Firecracker](https://github.com/ftiradob/MicroVM_firecracker#3-firecracker-1)
### [4. Requisitos previos](https://github.com/ftiradob/MicroVM_firecracker#4-requisitos-previos-1)
### [5. Puesta en marcha](https://github.com/ftiradob/MicroVM_firecracker#5-puesta-en-marcha-1)
#### [5.1. Mediante API Restful](https://github.com/ftiradob/MicroVM_firecracker#51-mediante-api-restful-1)
#### [5.2. Mediante fichero JSON](https://github.com/ftiradob/MicroVM_firecracker#52-mediante-fichero-json-1)
### [6. Creacion de kernel e imagen aptos para Firecracker](https://github.com/ftiradob/MicroVM_firecracker#6-creaci%C3%B3n-de-kernel-e-imagen-aptos-para-firecracker)
### [7. Configuración de red](https://github.com/ftiradob/MicroVM_firecracker#7-configuraci%C3%B3n-de-red-1)
### [8. Firectl](https://github.com/ftiradob/MicroVM_firecracker#8-firectl-1)
### [9. Script de automatización](https://github.com/ftiradob/MicroVM_firecracker#9-script-de-automatizaci%C3%B3n-1)
### [10. Conclusión](https://github.com/ftiradob/MicroVM_firecracker#10-conclusi%C3%B3n-1)
### [11. Webgrafía](https://github.com/ftiradob/MicroVM_firecracker#11-webgraf%C3%ADa-1)
### [12. Presentación en vídeo del proyecto](https://github.com/ftiradob/MicroVM_firecracker#12-presentaci%C3%B3n-en-v%C3%ADdeo-del-proyecto-1)




## 1. INTRODUCCIÓN

Una micro VM (micro máquina virtual) es una máquina virtual liviana, que tiene la seguridad de las máquinas virtuales tradicionales; y el rendimiento de los contenedores. Firecracker hace uso de KVM para crear y administrar estas micro VMs. Vamos a conocer en profundidad las características de este tipo de tecnología, posibles usos y demostración de su funcionamiento.



## 2. CONCEPTOS PREVIOS

* **Máquinas virtuales**

Entidad aislada con su propio SO en la que es posible instalar aplicaciones.

|Ventajas|Desventajas|
|--------|----------------------|
|Diferente kernel que la máquina real, más seguridad | Ralentización de máquina anfitriona |
|Múltiples entorno de SO aislados entre sí | Menor rendimiento que una máquina real, inicia SO completo
|Mantenimiento, disponibilidad y recuperación sencillos |
|Posibilidad de personalizar las características de la máquina |
|Portabilidad |
|Migración en vivo |


* **Contenedores**

Capacidad de ejecutar varios procesos y aplicaciones de forma aislada para hacer un mejor uso de su infraestructura, ya que no virtualiza un SO completo.

|Ventajas|Desventajas|
|--------|----------------------|
|Usan los recursos del anfitrión | Usa el kernel del anfitrión, menos seguridad |
|Gran rendimiento y agilidad | Ausencia de systemd
|Centrados en el desarrollo y despliegue de aplicaciones | Inestables en cuanto a almacenamiento
|Portabilidad |


## 3. FIRECRACKER


**Características**

* Software libre bajo la licencia de Apache
* Escrito en Rust
* Creado por desarrolladores de AWS

**Ventajas**

* Hace uso de un kernel Linux reducido y aislado para mayor rendimiento
* Hace uso de KVM para crear y gestionar las micro VM, un sistema nativo de Linux muy fiable
* Posibilidad de personalizar las características de la máquina
* Tiene almacenamiento persistente, ya que guarda los archivos que creamos en la imagen ".ext4"

**Desventajas**

* No esta en la paquetería oficial
* Escasa documentación


En nuestro caso hemos hecho las pruebas con Debian y con Alpine, un sistema orientado específicamente a la seguridad y a ser lo más ligero posible para consumir muy pocos recursos del sistema, por lo que tiene mucha sinergia con la tecnología MicroVM. Este SO cuenta con paquetería propia y con sistema de arranque OpenRC.

## 4. REQUISITOS PREVIOS

* Tener Kernel Linux 4.14 o superior

~~~
uname -a
~~~


* Tener KVM con permisos de lectura y escritura

~~~
sudo setfacl -m u:${USER}:rw /dev/kvm
~~~


## 5. PUESTA EN MARCHA

### 5.1. MEDIANTE API RESTFUL

Lo primero que tenemos que hacer es descargarnos el binario de Firecracker y darle permiso de ejecución. Opcionalmente, también podemos mover el binario a la ruta /usr/local/bin para que sea accesible para todos los usuarios.

~~~
wget https://github.com/firecracker-microvm/firecracker/releases/download/v0.21.1/firecracker-v0.21.1-x86_64
mv firecracker-v0.21.1-x86_64 firecracker
chmod +x firecracker
sudo mv firecracker /usr/local/bin/
~~~

Una vez hecho esto, debemos asegurarnos que Firecracker puede crear el socket para la API. Para esto lo que vamos a hacer primero es borrarlo por si había alguno existente:

~~~
rm -f /tmp/firecracker.socket
~~~

Ahora ya podemos crearlo:

~~~
./firecracker --api-sock /tmp/firecracker.socket
~~~

Una vez creado el socket, nos pasamos a una segunda shell, que es donde vamos a establecer una serie de parámetros mediante peticiones a la API.

En la primera llamada vamos a establecer el kernel:

~~~
kernel_path=$(pwd)"/hello-vmlinux.bin"

  curl --unix-socket /tmp/firecracker.socket -i \
  -X PUT 'http://localhost/boot-source'   \
  -H 'Accept: application/json'           \
  -H 'Content-Type: application/json'     \
  -d "{
        \"kernel_image_path\": \"${kernel_path}\",
        \"boot_args\": \"console=ttyS0 reboot=k panic=1 pci=off\"
   }"
~~~

En la segunda llamada vamos a establecer la imagen que va a tener nuestra micro máquina:

~~~
  rootfs_path=$(pwd)"/hello-rootfs.ext4"
  curl --unix-socket /tmp/firecracker.socket -i \
    -X PUT 'http://localhost/drives/rootfs' \
    -H 'Accept: application/json'           \
    -H 'Content-Type: application/json'     \
    -d "{
          \"drive_id\": \"rootfs\",
          \"path_on_host\": \"${rootfs_path}\",
          \"is_root_device\": true,
          \"is_read_only\": false
     }"
~~~

En la tercera llamada podremos modificar algunos de sus parámetros a nuestro gusto (si no lo hacemos, nos pondrá por defecto 1 vCPU y 128 MiB RAM):

~~~
curl --unix-socket /tmp/firecracker.socket -i  \
    -X PUT 'http://localhost/machine-config' \
    -H 'Accept: application/json'            \
    -H 'Content-Type: application/json'      \
    -d '{
        "vcpu_count": 2,
        "mem_size_mib": 1024,
        "ht_enabled": false
    }'
~~~

En la última llamada iniciaremos la micro máquina:

~~~
curl --unix-socket /tmp/firecracker.socket -i \
    -X PUT 'http://localhost/actions'       \
    -H  'Accept: application/json'          \
    -H  'Content-Type: application/json'    \
    -d '{
        "action_type": "InstanceStart"
     }'
~~~

### 5.2. MEDIANTE FICHERO JSON

Este método es mucho más eficaz, ya que simplemente rellenaremos un fichero JSON indicando las características de la micro máquina y la iniciaremos con un simple comando. Todavía podremos enviar peticiones a la API una vez iniciada la micro máquina. El fichero JSON tendrá este formato:

~~~
{
  "boot-source": {
    "kernel_image_path": "hello-vmlinux.bin",
    "boot_args": "console=ttyS0 reboot=k panic=1 pci=off"
  },
  "drives": [
    {
      "drive_id": "rootfs",
      "path_on_host": "hello-rootfs.ext4",
      "is_root_device": true,
      "is_read_only": false
    }
  ],
  "machine-config": {
    "vcpu_count": 2,
    "mem_size_mib": 1024,
    "ht_enabled": false
  }
}
~~~

Y la iniciaremos de la siguiente manera:

~~~
./firecracker --api-sock /tmp/firecracker.socket --config-file nombrejson.json
~~~

Ahora vamos a hacer una demostración sobre como levantar varias máquinas al mismo tiempo:

~~~
for ((i=0; i<30; i++)); do
    firecracker --api-sock /tmp/firecracker-$i.sock --config-file confibasica.json&
done
~~~

Cuando levantemos tantas, van a ponerse en segundo plano automáticamente, por lo que tendremos que:

~~~
fg
~~~

Cuando acabemos y querramos cerrar todas las máquinas de golpe:

~~~
pkill firecracker
~~~

## 6. CREACIÓN DE KERNEL E IMAGEN APTOS PARA FIRECRACKER


Lo primero que tenemos que hacer es crear una imagen vacía de por ejemplo 50 MB:

~~~
dd if=/dev/zero of=ferfs.ext4 bs=1M count=50
~~~

Le damos formato ext4, que es la que usa Firecracker:

~~~
sudo mkfs.ext4 ferfs.ext4
~~~

Ahora vamos a montarla:

~~~
mkdir /tmp/ferfs
sudo mount ferfs.ext4 /tmp/ferfs
~~~

Ahora levantamos un contenedor docker con la imagen que queramos, vinculándolo con el directorio en el que hemos montado la imagen:

~~~
sudo docker run -it --rm -v /tmp/ferfs:/ferfs alpine
~~~

Añadimos los componentes necesarios para el correcto funcionamiento y desmontamos:

~~~
passwd
apk add openrc
apk add util-linux

ln -s agetty /etc/init.d/agetty.ttyS0
echo ttyS0 > /etc/securetty
rc-update add agetty.ttyS0 default

rc-update add hostname boot
rc-update add devfs boot
rc-update add procfs boot
rc-update add sysfs boot

for d in bin etc lib root sbin usr; do tar c "/$d" | tar x -C /ferfs; done
for dir in dev proc run sys var; do mkdir /ferfs/${dir}; done

exit
~~~

Finalmente desmontamos y ya estamos listos para probar nuestra imagen:

~~~
sudo umount /tmp/ferfs
~~~


## 7. Configuración de red

Para hacer esto, haremos uso de una interfaz de red virtual usando tap. Vamos a crearla:

~~~
sudo ip tuntap add tap0 mode tap
~~~

Tras esto vamos a establecer las diferentes opciones para nuestra red:

~~~
sudo ip addr add 172.16.0.1/24 dev tap0
sudo ip link set tap0 up
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
sudo iptables -t nat -A POSTROUTING -o wlo1 -j MASQUERADE
sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i tap0 -o wlo1 -j ACCEPT
~~~

Y añadimos la siguiente sección al archivo JSON:

~~~
"network-interfaces": [
  {
    "iface_id": "eth0",
    "guest_mac": "AA:FC:00:00:00:01",
    "host_dev_name": "tap0"
  }
]
~~~

Finalmente, una vez dentro de la máquina, podremos conectarnos a la interfaz creada de la siguiente manera:

~~~
ip addr add 172.16.0.2/24 dev eth0
ip route add default via 172.16.0.1 dev eth0
echo "nameserver 8.8.8.8" > /etc/resolv.conf
~~~

## 8. FIRECTL

Es una extensión de Firecracker que te permite poner en marcha las micro máquinas sin necesidad de API ni archivos JSON ni dos terminales, sino directamente mediante línea de comandos.

Para descargar el binario de esta extensión necesitaremos hacer lo siguiente:

~~~
git clone https://github.com/firecracker-microvm/firectl
cd firectl
sudo make build-in-docker
~~~

Vamos a poner un ejemplo de uso:

~~~
sudo ./firectl \
				--firecracker-binary=./firecracker \
				--kernel=alpine-vmlinuz.bin \
				--root-drive=alpine.ext4 \
				--cpu-template=T2 \
				--kernel-opts="console=ttyS0 noapic reboot=k panic=1 pci=off nomodules ro" \
				-c 2 \
				-m 512 \
				--tap-device=tap0/02:01:7b:68:47:11 \
				--socket-path=./firecracker.socket
~~~

## 9. SCRIPT DE AUTOMATIZACIÓN

Con el siguiente script podremos:

 - Descarga inmediata de binarios Firecracker y Firectl
 - Elegir entre Alpine o Debian
 - Personalización de número de nucleos de cada microvm
 - Personalización de memoria RAM de cada microvm
 - Posibilidad de añadir red a la microvm
 - Arrancar rápidamente microvm totalmente funcionales

El script es el siguiente:

~~~
#! /bin/sh

while :
do

echo ""
echo "~~~~~ CREACIÓN DE MICROVM ~~~~~"
echo ""
echo "1. Alpine"
echo "2. Debian"
echo "0. Salir"
read -p "Elija un sistema operativo: " opcion
echo ""

# Elección de sistema operativo

case $opcion in

1)

kernel=imagenes/alpine-vmlinuz.bin
imagen=imagenes/alpine.ext4
break
;;

2)

kernel=imagenes/debian-vmlinuz.bin
imagen=imagenes/debian.ext4
break
;;

0) exit;;

*) echo "Error de opción";;

esac
done

# Configuración de núcleos
read -p "Elija el número de nucleos (mínimo 1): " nucleos
echo ""

# Configuración de RAM
read -p "Elija la cantidad de memoria RAM (mínimo 128): " ram
echo ""

# Configuración de red
while :
do
	read -p "¿Desea tener conexión a internet? [S/N] " internet
	if [ $internet = "S" ] || [ $internet = "s" ]
	then
		echo "Configurando la red.."
		sudo ip tuntap add tap0 mode tap
		tap0_mac=$(cat /sys/class/net/tap0/address)
		sudo ip addr add 172.16.0.1/24 dev tap0
		sudo ip link set tap0 up
		sudo sh -c 'echo 1 > /proc/sys/net/ipv4/ip_forward'
		interfaz_defecto=$(ip route | grep default | awk '{print $5}')
		sudo iptables -t nat -A POSTROUTING -o $interfaz_defecto -j MASQUERADE
		sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
		sudo iptables -A FORWARD -i tap0 -o $interfaz_defecto -j ACCEPT
		echo ""
		echo "IMPORTANTE!! Para el correcto funcionamiento de la red, debe insertar el siguiente"
		echo "script en la nueva microvm creada"
		echo "----------------------------------------------------------"
		echo "ip addr add 172.16.0.2/24 dev eth0"
		echo "ip route add default via 172.16.0.1 dev eth0"
		echo 'echo "nameserver 8.8.8.8" > /etc/resolv.conf'
		echo "----------------------------------------------------------"
		echo ""
		break
	elif [ $internet = "N" ] || [ $internet = "n" ]
	then
		echo "Rechazando internet.."
		sleep 3
		clear
		break
	else
		echo "Error de opción"
	fi
done

# Credenciales

echo ""
echo "CREDENCIALES"
echo "------------"
echo ""
echo "Usuario: root"
echo "Contraseña: root"
echo ""

# Puesta en marcha de la máquina

naleatorio=$(shuf -i 0-10 -n 1)

if [ $internet = "S" ] || [ $internet = "s" ]
then
	sudo ./firectl \
				--firecracker-binary=./firecracker \
				--kernel=$kernel \
				--root-drive=$imagen \
				--cpu-template=T2 \
				--kernel-opts="console=ttyS0 noapic reboot=k panic=1 pci=off nomodules ro" \
				-c $nucleos \
				-m $ram \
				--tap-device=tap0/$tap0_mac \
				--socket-path=./firecracker-$naleatorio.socket
else
	sudo ./firectl \
				--firecracker-binary=./firecracker \
				--kernel=$kernel \
				--root-drive=$imagen \
				--cpu-template=T2 \
				--kernel-opts="console=ttyS0 noapic reboot=k panic=1 pci=off nomodules ro" \
				-c $nucleos \
				-m $ram \
				--socket-path=./firecracker-$naleatorio.socket
fi
~~~

Instrucciones de uso:

~~~
git clone https://github.com/ftiradob/MicroVM_firecracker
sh automicrovm.sh
~~~

## 10. CONCLUSIÓN

Es una tecnología muy util que en el futuro tiene bastante potencial como para "ponerse de moda" como ocurre ahora mismo con los contenedores. Necesita todavía un empujón de los desarrolladores y de la comunidad para que el proyecto cuente con el menor número de errores posibles, mejor documentación e incluso llegue a formar parte de la paquetería oficial Debian. Las micro VM son un excelente punto intermedio entre una máquina virtual tradicional pesada y un contenedor de aplicaciones ligero.

## 11. WEBGRAFÍA

Amazon Web Services (2018 - 2020) - Página oficial de Firecracker
[https://firecracker-microvm.github.io/](https://firecracker-microvm.github.io/)

Amazon Web Services (2018 - 2020) - Repositorio oficial de Firecracker
[https://github.com/firecracker-microvm/firecracker](https://github.com/firecracker-microvm/firecracker)

Amazon Web Services (2018 - 2020) - Repositorio oficial de Firectl
[https://github.com/firecracker-microvm/firectl](https://github.com/firecracker-microvm/firectl)

Swarvanu Sengupta (2019) - Blog explicativo sobre Firectl
[https://medium.com/@s8sg/quick-start-with-firecracker-and-firectl-in-ubuntu-f58aeedae04b](https://medium.com/@s8sg/quick-start-with-firecracker-and-firectl-in-ubuntu-f58aeedae04b)

## 12. PRESENTACIÓN EN VÍDEO DEL PROYECTO

Si les ha interesado el proyecto, pueden verlo presentado en vídeo por mi mismo haciendo clic [aquí](https://www.youtube.com/watch?v=o1oEhw5tXjQ).
