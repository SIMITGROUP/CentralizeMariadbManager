#!/bin/bash
PARA=$1

if [ $PARA  = "start" ] ;then 
	/usr/sbin/php-fpm7.2;
	chmod 777 /var/php-fpm/${USER}.sock
elif [ $PARA = "stop" ] ;then
	kill  `cat /var/php-fpm/${USER}.pid`;
elif [ $PARA = "restart" ] ;then
	 kill  `cat /var/php-fpm/${USER}.pid`;
	  /usr/sbin/php-fpm7.2;
	   chmod 777 /var/php-fpm/${USER}.sock

elif [ $PARA = "status" ] ; then
	if [ -f "/var/php-fpm/${USER}.pid" ] ; then
		echo "${USER} have php-fpm process running"
	else
		echo "no php-fpm process is running"
	fi
else
	echo 'Unknown parameter, please submit "start", "restart","stop", or "status" parameter';
fi


if [ ! -d "/var/www/html/$USER" ]
	then
                ln -s /var/www/html/db /var/www/html/$USER;
fi
