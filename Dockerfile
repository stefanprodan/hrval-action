FROM golang:1.15.1 AS gobuilder

WORKDIR /app
COPY src/go src/go

RUN mkdir build
RUN go get gopkg.in/yaml.v2
RUN go get github.com/google/uuid
RUN go test -json src/go/*
RUN go build -o build src/go/valuesfrom.go


FROM garethr/kubeval:0.15.0

RUN apk --no-cache add curl bash git openssh-client libc6-compat

COPY LICENSE README.md /

COPY src/deps.sh /deps.sh
RUN /deps.sh

COPY src/hrval.sh /usr/local/bin/hrval.sh
COPY src/hrval-all.sh /usr/local/bin/hrval
COPY --from=gobuilder /app/build/valuesfrom /usr/local/bin/valuesfrom

ENTRYPOINT ["hrval"]
