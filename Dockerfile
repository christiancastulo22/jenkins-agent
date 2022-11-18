# Image installs with latest Java OpenJDK on Alpine Linux
# FROM adoptopenjdk/openjdk11:${JDK_VERSION}
FROM alpine

USER root

# Update and upgrade apk then install curl, maven, git, and nodejs
RUN apk update && \
    apk upgrade && \
    apk --no-cache add curl && \
    apk --no-cache add maven && \
    apk --no-cache add git && \
    apk --no-cache add docker

# Create workspace directory for Jenkins
RUN mkdir /workspace \
    && chmod 777 /workspace \
    && mkdir -p /usr/share/jenkins \
    && chmod 777 /usr/share/jenkins


ARG SWARM_CLIENT_VERSION="3.37"
# Download the latest Jenkins swarm client with curl - version ${SWARM_CLIENT_VERSION}
# Browse all versions here: https://repo.jenkins-ci.org/releases/org/jenkins-ci/plugins/swarm-client/
RUN curl -o /usr/share/jenkins/agent.jar https://repo.jenkins-ci.org/releases/org/jenkins-ci/plugins/swarm-client/${SWARM_CLIENT_VERSION}/swarm-client-${SWARM_CLIENT_VERSION}.jar

ENV JENKINS_HOST=""
ENV JENKINS_USER=""
ENV JENKINS_TOKEN=""
ENV AGENT_NAME="swarm-client"

CMD java -jar /usr/share/jenkins/agent.jar -url "${JENKINS_HOST}" -username "${JENKINS_USER}" -password "${JENKINS_TOKEN}" -name "${AGENT_NAME}"