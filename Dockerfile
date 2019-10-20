FROM golang:1.13

COPY LICENSE README.md /
COPY src/ /
RUN /deps.sh

ENTRYPOINT ["/hrval-all.sh"]
