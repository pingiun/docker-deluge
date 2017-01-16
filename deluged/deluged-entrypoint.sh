#!/bin/bash

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

if [ "${1:0:1}" = '-' ]; then
	set -- deluged "$@"
fi

if [ "$1" = 'deluged' ]; then
	mkdir -p "$DLDATA"

	if [ ! -s "/config/auth/state" ]; then

		file_env 'POSTGRES_PASSWORD'

		if [ "$DELUGE_PASSWORD" ]; then
			pass=$DELUGE_PASSWORD
		else
			cat >&2 <<-'EOWARN'
				****************************************************
				WARNING: No password has been set for deluge.
				         This will allow anyone with access to the
				         Deluge port to access deluge with the 
				         default password (password). In
				         Docker's default configuration, this is
				         effectively any other container on the same
				         system.
				         Use "-e DELUGE_PASSWORD=password" to set
				         it in "docker run".
				****************************************************
			EOWARN

			pass="password"
		fi

		file_env 'DELUGE_USER' 'deluge'

		echo "$DELUGE_USER:$pass:10" >> /config/auth

		echo
		echo 'Deluge init process complete; ready for start up.'
		echo
	fi

	exec deluged -d -c /config "$@"

fi

exec "$@"

