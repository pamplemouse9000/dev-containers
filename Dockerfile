# Alpine docker image with AWS CLI version 2
#   - kubectl
#   - saml2aws
#   - ...
# Ref: https://stackoverflow.com/questions/60298619/awscli-version-2-on-alpine-linux

# Set an argument for the Alpine Linux version
ARG ALPINE_VERSION=3.16

# Use Python 3.10.5 Alpine Linux image as the builder stage
FROM python:3.10.5-alpine${ALPINE_VERSION} as builder

ARG AWS_CLI_VERSION=2.9.0
RUN apk add --no-cache git unzip groff build-base libffi-dev cmake curl 
RUN git clone --single-branch --depth 1 -b ${AWS_CLI_VERSION} https://github.com/aws/aws-cli.git

# Build AWS CLI executable and install to /aws-cli-bin
WORKDIR aws-cli
RUN python -m venv venv && \
    . venv/bin/activate && \
    scripts/installers/make-exe && \
    unzip -q dist/awscli-exe.zip && \
    aws/install --bin-dir /aws-cli-bin && \
    /aws-cli-bin/aws --version

# Install kubectl and saml2aws
ARG KUBECTL_VERSION=1.21.0

RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl

ARG SAML2AWS_VERSION=2.36.4 
RUN curl -sSL https://github.com/Versent/saml2aws/releases/download/v${SAML2AWS_VERSION}/saml2aws_${SAML2AWS_VERSION}_linux_amd64.tar.gz -o saml2aws.tar.gz 
RUN tar xzf saml2aws.tar.gz && \
    mv saml2aws /usr/local/bin/ && \
    rm -rf saml2aws.tar.gz



# Remove autocomplete and example files to reduce image size
RUN rm -rf /usr/local/aws-cli/v2/current/dist/aws_completer \
    /usr/local/aws-cli/v2/current/dist/awscli/data/ac.index \
    /usr/local/aws-cli/v2/current/dist/awscli/examples && \
    find /usr/local/aws-cli/v2/current/dist/awscli/data -name completions-1*.json -delete && \
    find /usr/local/aws-cli/v2/current/dist/awscli/botocore/data -name examples-1.json -delete

# Use Alpine Linux image as the final stage
FROM alpine:${ALPINE_VERSION}

# Copy AWS CLI files and binary from the builder stage to final stage
COPY --from=builder /usr/local/aws-cli/ /usr/local/aws-cli/
COPY --from=builder /aws-cli-bin/ /usr/local/bin/

# Copy kubectl and saml2aws binaries from the builder stage to final stage
COPY --from=builder /usr/local/bin/kubectl /usr/local/bin/
COPY --from=builder /usr/local/bin/saml2aws /usr/local/bin/
