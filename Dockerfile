FROM loftsh/alpine:latest

ADD install.sh .
RUN chmod +x install.sh && ./install.sh

ADD run.sh /
ENTRYPOINT ["/run.sh"]