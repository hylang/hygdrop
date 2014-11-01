# Run hygdrop
#
# VERSION 0.2

FROM hylang:0.10.1

MAINTAINER Vasudev Kamath <kamathvasudev@gmail.com>

ADD . /opt/hygdrop
WORKDIR /opt/hygdrop
RUN pip3 install -r requirements-docker.txt

CMD ["hy", "./hygdrop.hy"]
