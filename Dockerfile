ARG BUILD_FROM
FROM ${BUILD_FROM}

RUN apk add --no-cache bash coreutils

COPY run.sh /
RUN chmod a+x /run.sh

ENTRYPOINT []
CMD [ "/bin/bash", "/run.sh" ]
