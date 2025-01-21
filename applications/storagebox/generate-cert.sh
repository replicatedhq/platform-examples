#!/bin/bash
set -e

usage() {
    echo "Usage: $0 <domain> [-i <ip1,ip2,...>]"
    exit 1
}

if [ -z "$1" ]; then
    usage
fi

DOMAIN="$1"
shift

IP_SANS=()

# Parse options
while getopts "i:" opt; do
    case $opt in
        i)
            IFS=',' read -r -a IP_SANS <<< "$OPTARG"
            ;;
        *)
            usage
            ;;
    esac
done

WILDCARD_DOMAIN="*.$DOMAIN"
CERT_DIR="$(pwd)"
CA_KEY="${CERT_DIR}/ca.key"
CA_CERT="${CERT_DIR}/ca.pem"
SERVER_KEY="${CERT_DIR}/server.key"
SERVER_CSR="${CERT_DIR}/server.csr"
SERVER_CERT="${CERT_DIR}/server.crt"
SAN_CONFIG="${CERT_DIR}/san.cnf"

COUNTRY="US"
STATE="State"
LOCALITY="City"
ORGANIZATION="Replicated"
ORGANIZATIONAL_UNIT="IT"

create_config() {
    cat > "${SAN_CONFIG}" <<EOL
[req]
distinguished_name = req_distinguished_name
req_extensions = req_ext
prompt = no
[req_distinguished_name]
C = ${COUNTRY}
ST = ${STATE}
L = ${LOCALITY}
O = ${ORGANIZATION}
OU = ${ORGANIZATIONAL_UNIT}
CN = ${WILDCARD_DOMAIN}
[req_ext]
subjectAltName = @alt_names
[v3_ca]
subjectAltName = @alt_names
basicConstraints = CA:true
[alt_names]
DNS.1 = ${WILDCARD_DOMAIN}
DNS.2 = ${DOMAIN}
EOL

    # Add IP addresses to SAN config
    if [ ${#IP_SANS[@]} -gt 0 ]; then
        for i in "${!IP_SANS[@]}"; do
            echo "IP.$((i+1)) = ${IP_SANS[$i]}" >> "${SAN_CONFIG}"
        done
    fi
}

create_ca() {
    openssl req -new -newkey rsa:2048 -sha256 \
        -days 365 -nodes -x509 -extensions v3_ca \
        -keyout "${CA_KEY}" \
        -out "${CA_CERT}" \
        -config "${SAN_CONFIG}" \
        -subj "/C=${COUNTRY}/ST=${STATE}/L=${LOCALITY}/O=${ORGANIZATION}/OU=${ORGANIZATIONAL_UNIT}/CN=${WILDCARD_DOMAIN}"
}

create_server_cert() {
    openssl genrsa -out "${SERVER_KEY}" 2048
    openssl req \
        -new \
        -key "${SERVER_KEY}" \
        -out "${SERVER_CSR}" \
        -config "${SAN_CONFIG}" \
        -extensions req_ext \
        -subj "/C=${COUNTRY}/ST=${STATE}/L=${LOCALITY}/O=${ORGANIZATION}/OU=${ORGANIZATIONAL_UNIT}/CN=${WILDCARD_DOMAIN}"
    openssl x509 \
        -req \
        -in "${SERVER_CSR}" \
        -CA "${CA_CERT}" \
        -CAkey "${CA_KEY}" \
        -CAcreateserial \
        -extfile "${SAN_CONFIG}" \
        -extensions req_ext \
        -out "${SERVER_CERT}" \
        -days 365 \
        -sha256
}

main() {
    create_config
    create_ca
    create_server_cert
}

main
