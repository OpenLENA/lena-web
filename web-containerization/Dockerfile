ARG FROM_IMAGE=centos:7
FROM docker.io/${FROM_IMAGE}

ENV LENA_HOME /usr/local/lena
ENV JAVA_HOME /usr/lib/jvm/java
ENV SERVER_NAME webServer
ENV SERVICE_PORT 7180

# create LENA HOME
RUN mkdir -p /usr/local/lena
# copy LENA install files
COPY web-dist/target/lena-work/*.tar.gz web-containerization/install.sh web-containerization/entrypoint.sh ${LENA_HOME}

# Insall LENA
RUN cd ${LENA_HOME} \
	&& chmod +x *.sh \
	&& ${LENA_HOME}/install.sh \
	&& rm -f ${LENA_HOME}/install.sh

WORKDIR $LENA_HOME
CMD ["./entrypoint.sh"]
