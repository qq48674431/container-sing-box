FROM alpine:latest
RUN apk add --no-cache ca-certificates iptables ip6tables
WORKDIR /opt/sing-box
COPY sing-box config.json index.html proxy-parser.js /opt/sing-box/
RUN chmod +x /opt/sing-box/sing-box
EXPOSE 8080
CMD ["/opt/sing-box/sing-box", "run", "-c", "/opt/sing-box/config.json"]
