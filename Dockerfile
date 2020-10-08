FROM garethr/kubeval:0.15.0

RUN apk --no-cache add curl==7.67.0-r1 bash==5.0.11-r1 git==2.24.3-r0 openssh-client==8.1_p1-r0

COPY LICENSE README.md /

COPY src/deps.sh /deps.sh
RUN /deps.sh

COPY src/hrval.sh /usr/local/bin/hrval.sh
COPY src/hrval-all.sh /usr/local/bin/hrval

ENTRYPOINT ["hrval"]
