IMAGE=tercen/runtime-r40:4.0.4-1

USER root
WORKDIR /operator

RUN apt-get update
RUN apt-get install -y tk

RUN git clone https://github.com/tercen/flowsom_operator.git

WORKDIR /operator/flowsom_operator

RUN echo 0.1.0 && git pull
RUN git checkout 0.1.0

RUN R -e "renv::restore(confirm=FALSE)"

ENV TERCEN_SERVICE_URI https://tercen.com

COPY start.R /start.R

ENTRYPOINT [ "R","--no-save","--no-restore","--no-environ","--slave","-f","/start.R"]