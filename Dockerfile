FROM garethr/kubeval:0.15.0

RUN apk --no-cache add curl bash git openssh-client

COPY LICENSE README.md /

COPY src/deps.sh /deps.sh
RUN /deps.sh

COPY src/hrval.sh /usr/local/bin/hrval.sh
COPY src/hrval-all.sh /usr/local/bin/hrval

ENTRYPOINT ["hrval"]
