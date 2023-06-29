#!/bin/bash

service nginx start
service postgresql start
service php7.4-fpm start

tail -f /var/log/nginx/*log /var/log/postgresql/postgresql-14-main.log /var/log/php7.4-fpm.log

