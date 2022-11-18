config_file_path="./config.yaml"

ROUND_ROBIN=$(echo "${ROUND_ROBIN}" | tr A-Z a-z)
if [ "${ROUND_ROBIN}" != "true" ]
then
    ROUND_ROBIN="false"
else
    ROUND_ROBIN="true"
fi


LISTEN_PORT=$(echo "${LISTEN_PORT}" | tr -dc '0-9')
if [ -z "${LISTEN_PORT}" ] ; then 
    LISTEN_PORT=9443
fi

check_keys () {
    if [ -z "${PAA_SIG}" ] && [ ${#PAA_SIG} -eq 32 ] ; then 
        PAA_SIG=$( tr -dc A-Za-z0-9 </dev/urandom | head -c 32 )
    fi
    
    if [ -z "${PAA_ENC}" ] && [ ${#PAA_ENC} -eq 32 ] ; then 
        PAA_ENC=$( tr -dc A-Za-z0-9 </dev/urandom | head -c 32 )
    fi

    if [ -z "${SES_KEY}" ] && [ ${#SES_KEY} -eq 32 ] ; then 
        SES_KEY=$( tr -dc A-Za-z0-9 </dev/urandom | head -c 32 )
    fi
    
    if [ -z "${SES_ENC}" ] && [ ${#SES_ENC} -eq 32 ] ; then 
        SES_ENC=$( tr -dc A-Za-z0-9 </dev/urandom | head -c 32 )
    fi
}

check_keys

cat > "${config_file_path}" <<-EOF
Client:
 UsernameTemplate: "{{ username }}"
 NetworkAutoDetect: 0
 BandwidthAutoDetect: 1
 ConnectionType: 6
Security:
  PAATokenSigningKey: "${PAA_SIG}"
  paatokenencryptionkey: "${PAA_ENC}"
Server:
 CertFile: /opt/rdpgw/server.pem
 KeyFile: /opt/rdpgw/key.pem
 GatewayAddress: ${GW_ADD}
 Port: ${LISTEN_PORT}
 RoundRobin: §{ROUND_ROBIN}
 SessionKey: "${SES_KEY}"
 SessionEncryptionKey: ${SES_ENC}"
 Hosts:
  - xrdp:3389 
EOF

gen_hosts () {
    ALLOWED_HOSTS=$(echo "${ALLOWED_HOSTS}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
    if [ ! -z "${ALLOWED_HOSTS}" ]; then
    	#IFS=',' read -ra hosts_list <<< "${ALLOWED_HOSTS}"
    	echo " Hosts:" >> "${config_file_path}"
    	sec="\n  - "
    	output=$(echo "  - $ALLOWED_HOSTS" | sed 's/,/\n  - /g' )
    	echo "$output"

    	#echo "${ALLOWED_HOSTS/,/$sec}"
    	#>> "${config_file_path}"

    else
    	echo "::: ALLOWED_HOSTS not defined"
    fi
}

gen_hosts


check_auth () {
    if [ "${AUTH}" = "LOCAL" ]; then
        cat >> "${config_file_path}" <<-EOF
Caps:
 TokenAuth: false        
Authentication: 
  - local
EOF
    else
        cat >> "${config_file_path}" <<-EOF
Caps:
 TokenAuth: true
Authentication:
  - openid
OpenId:
 ProviderUrl: ${OIDC_URL}
 ClientId: ${OIDC_ID}
 ClientSecret: ${OIDC_SEC}
EOF
    fi
}

check_auth

exec /opt/rdpgw/rdpgw