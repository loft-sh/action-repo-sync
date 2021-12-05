FROM alpine:3.14

ADD install.sh .
RUN chmod +x install.sh && ./install.sh

ADD run.sh .
ENTRYPOINT ["/run.sh"]