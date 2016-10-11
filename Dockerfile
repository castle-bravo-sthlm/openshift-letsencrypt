FROM openshift/base-centos7

ENV LETSENCRYPT_SH_COMMIT=a316a094df8d3d4b25673cfbb1197f646781e48f \
    LETSENCRYPT_DATADIR=/var/lib/letsencrypt-container \
    LETSENCRYPT_LIBEXECDIR=/usr/libexec/letsencrypt-container \
    LETSENCRYPT_SHAREDIR=/usr/share/letsencrypt-container


USER 0

RUN curl -sSL https://github.com/lukas2511/dehydrated/raw/$LETSENCRYPT_SH_COMMIT/dehydrated \
         -o /usr/bin/dehydrated \
 && chmod +x /usr/bin/dehydrated \
 && yum install -y openssl curl nss_wrapper jq \
 && yum clean all

USER 1001

ADD libexec/ $LETSENCRYPT_LIBEXECDIR
ADD share/ $LETSENCRYPT_SHAREDIR

ENTRYPOINT ["/usr/libexec/letsencrypt-container/entrypoint"]
CMD ["usage"]
