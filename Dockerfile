# Setup build arguments with default versions
ARG AWS_CLI_VERSION
ARG TERRAFORM_VERSION
ARG PYTHON_VERSION=3
ARG PYTHON_MAJOR_VERSION=3.9
ARG UBUNTU_VERSION=20.04
ARG TZ=US/Pacific
ARG DEBIAN_FRONTEND=noninteractive

# Download Terraform binary
FROM ubuntu:${UBUNTU_VERSION} as terraform
ARG TERRAFORM_VERSION
RUN apt-get update
RUN apt-get install --no-install-recommends -y curl
RUN apt-get install --no-install-recommends -y ca-certificates
RUN apt-get install --no-install-recommends -y unzip
RUN apt-get install --no-install-recommends -y gnupg
RUN apt-get install --no-install-recommends -y software-properties-common

WORKDIR /workspace
RUN curl -Os https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS
RUN curl -Os https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
RUN curl -Os https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS.sig
COPY hashicorp.asc hashicorp.asc
RUN gpg --import hashicorp.asc
RUN gpg --verify terraform_${TERRAFORM_VERSION}_SHA256SUMS.sig terraform_${TERRAFORM_VERSION}_SHA256SUMS
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN grep terraform_${TERRAFORM_VERSION}_linux_amd64.zip terraform_${TERRAFORM_VERSION}_SHA256SUMS | sha256sum -c -
RUN unzip -j terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# Build final image with AWS CLI
FROM ubuntu:${UBUNTU_VERSION}
LABEL maintainer="ocm team"
ARG PYTHON_MAJOR_VERSION
ARG AWS_CLI_VERSION
ARG TERRAFORM_VERSION
ARG PYTHON_MAJOR_VERSION
ADD ca-certs /usr/local/share/ca-certificates

# Set the TimeZone details
RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN apt-get update && apt-get -y install tzdata

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    jq \
    unzip \
    vim \
    curl \
    python${PYTHON_MAJOR_VERSION} \
    libpython${PYTHON_MAJOR_VERSION}-dev \
    python3-pip \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && update-alternatives --install /usr/bin/python python /usr/bin/python${PYTHON_MAJOR_VERSION} 1

# Install Setuptools and test tools
RUN pip3 install --no-cache-dir setuptools
RUN pip3 install -U pytest
RUN pip3 install -U pytest-cov
RUN pip3 install -U boto3


# Download and install the AWS CLI  binary
# Ref: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip
RUN ./aws/install

# Copy Terraform details to Final build
RUN dpkg-reconfigure --frontend noninteractive tzdata
WORKDIR /workspace
COPY --from=terraform /workspace/terraform /usr/local/bin/terraform

# Create a jenkins user
RUN groupadd --gid 1001 jenkins \
  # user needs a home folder to store aws credentials
  && useradd --gid jenkins --create-home --uid 1001 jenkins \
  && chown jenkins:jenkins /workspace
USER jenkins

CMD ["bash"]
