# FROM IMAGE will be changed by docker build argument
ARG FROM_IMAGE=MustInputBuildArg
FROM docker.io/${FROM_IMAGE}

ENV LAT_HOME /usr/local/lat
#ARG JDK_HOME=/usr/lib/jvm/java
#ENV JAVA_HOME ${JDK_HOME}
ENV SERVER_NAME webServer
ENV SERVICE_PORT 7180

# create LA:T HOME
RUN mkdir -p /usr/local/lat
# copy LA:T install files
COPY web-dist/target/lat-work/*.tar.gz web-containerization/install.sh web-containerization/entrypoint.sh ${LAT_HOME}

# Insall LA:T
RUN cd ${LAT_HOME} \
	&& chmod +x *.sh \
	&& ${LAT_HOME}/install.sh \
	&& rm -f ${LAT_HOME}/install.sh

WORKDIR $LAT_HOME
CMD ["./entrypoint.sh"]
