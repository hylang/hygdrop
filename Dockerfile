# Run hygdrop
#
# VERSION 0.2

FROM hylang:0.10.1

MAINTAINER Vasudev Kamath <kamathvasudev@gmail.com>

COPY requirements.txt /tmp/
RUN pip3 install -r /tmp/requirements.txt
ADD . /opt/hygdrop

WORKDIR /opt/hygdrop

CMD ["hy", "./hygdrop.hy"]
