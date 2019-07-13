#!/bin/bash

service nginx start
service postgresql start
service php7.2-fpm start

tail -f /var/log/nginx/*log /var/log/postgresql/postgresql-11-main.log /var/log/php7.2-fpm.log

