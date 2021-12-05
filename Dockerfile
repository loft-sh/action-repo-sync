FROM alpine:3.14

ADD install.sh .
RUN ./install.sh

ADD run.sh .
ENTRYPOINT ["/run.sh"]