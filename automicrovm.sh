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
