FROM alpine:3

RUN apk --update --no-cache add nodejs nodejs-npm python3 py3-pip jq curl bash git docker && \
	ln -sf /usr/bin/python3 /usr/bin/python && \
	npm install -g yarn

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
