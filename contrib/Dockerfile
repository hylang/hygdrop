# Run hygdrop
#
# VERSION 0.1

FROM debian:sid
MAINTAINER Vasudev Kamath <kamathvasudev@gmail.com>



# Lets install python3 and pip and git
RUN apt-get update && apt-get install -y python3 python3-pip git
RUN git clone https://github.com/hylang/hygdrop.git
RUN pip3 install -r hygdrop/requirements.txt

ENTRYPOINT ["hy", "hygdrop/hygdrop.hy"]
