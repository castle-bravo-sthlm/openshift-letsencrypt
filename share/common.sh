export LETSENCRYPT_SERVICE_NAME=${LETSENCRYPT_SERVICE_NAME-letsencrypt}
export LETSENCRYPT_ALL_NAMESPACES=${LETSENCRYPT_ALL_NAMESPACES-no}
export LETSENCRYPT_DEFAULT_INSECURE_EDGE_TERMINATION_POLICY="${LETSENCRYPT_DEFAULT_INSECURE_EDGE_TERMINATION_POLICY-edge}"
export LETSENCRYPT_ROUTE_SELECTOR="${LETSENCRYPT_ROUTE_SELECTOR-butter.sh/letsencrypt-managed=yes}"

export OC_GET_ROUTES="oc get routes"
case $LETSENCRYPT_ALL_NAMESPACES in
    yes|y|true|t)
        OC_GET_ROUTES="oc get routes --all-namespaces"
        ;;
    *)
        ;;
esac

if [ -n "$LETSENCRYPT_ROUTE_SELECTOR" ]; then
    OC_GET_ROUTES="$OC_GET_ROUTES -l $LETSENCRYPT_ROUTE_SELECTOR"
fi

err() {
    echo "$@" >&2
}

patch_route() {
    oc patch -n $1 route/$2 -p "$3" > /dev/null
}

json_escape() {
    python -c 'import json,sys; print json.dumps(sys.stdin.read())'
}

crt_enddate() {
    date -Iseconds -u --date "$(openssl x509 -noout -enddate -in "$1" | cut -d= -f2)"
}

date_in_secs() {
    date -u -d "$1" +%s
}

valid_secrets_selector() {
    DOMAINNAME="$1"
    if [ $# -eq 2 ]; then
        MIN_VALID_SECS="$2"
    else
        MIN_VALID_SECS="$(( $(date -u +%s) + 60*60*24*$LETSENCRYPT_RENEW_BEFORE_DAYS))"
    fi

    xargs <<EOF
butter.sh/letsencrypt-crt-enddate-secs > $min_valid_secs,
butter.sh/letsencrypt-domainname = $DOMAINNAME
EOF
}


hpkp_sha256() {
    case $LETSENCRYPT_KEYTYPE in
        rsa)
            openssl rsa -in "$1" -outform der -pubout 2>/dev/null \
                | openssl dgst -sha256 -binary | openssl enc -base64
            ;;
        *)
            # every other key type is an elliptic curve
            openssl ec -in "$1" -outform der -pubout 2>/dev/null \
                | openssl dgst -sha256 -binary | openssl enc -base64
            ;;
    esac
}

add_well_known_route() {
    export DOMAINNAME="$1"
    export TEMP_ROUTE_NAME="letsencrypt-$LETSENCRYPT_HOSTNAME"

    envsubst '$DOMAINNAME:$LETSENCRYPT_SERVICE_NAME:$TEMP_ROUTE_NAME' \
        < $LETSENCRYPT_SHAREDIR/new-well-known-route.yaml.tmpl \
        | oc create -f - 1>&2

    echo "$TEMP_ROUTE_NAME"
}
