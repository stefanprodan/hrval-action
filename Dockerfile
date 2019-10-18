FROM golang:1.13

COPY LICENSE README.md entrypoint.sh /
COPY ./src/hrval.sh /hrval.sh

ENTRYPOINT ["/entrypoint.sh"]


