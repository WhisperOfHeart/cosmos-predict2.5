# SPDX-FileCopyrightText: Copyright (c) 2025 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Dockerfile using uv environment.

ARG TARGETPLATFORM
ARG BASE_IMAGE=nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04

FROM ${BASE_IMAGE}

# Set the DEBIAN_FRONTEND environment variable to avoid interactive prompts during apt operations.
ENV DEBIAN_FRONTEND=noninteractive

# Install packages
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        ffmpeg \
        git \
        libgl1 \
        libglib2.0-0 \
        tree \
        wget && \
    rm -rf /var/lib/apt/lists/*

# Install uv: https://docs.astral.sh/uv/getting-started/installation/
# https://github.com/astral-sh/uv-docker-example/blob/main/Dockerfile
COPY --from=ghcr.io/astral-sh/uv:0.8.12 /uv /uvx /usr/local/bin/
# Enable bytecode compilation
ENV UV_COMPILE_BYTECODE=1
# Copy from the cache instead of linking since it's a mounted volume
ENV UV_LINK_MODE=copy
# Ensure installed tools can be executed out of the box
ENV UV_TOOL_BIN_DIR=/usr/local/bin

# Install just: https://just.systems/man/en/pre-built-binaries.html
RUN curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin --tag 1.42.4

WORKDIR /workspace

# Copy the project files needed for installation and execution
COPY uv.lock pyproject.toml .python-version ./
COPY packages ./packages
COPY cosmos_predict2 ./cosmos_predict2
COPY scripts ./scripts
COPY bin ./bin
COPY tools ./tools

# Install the project's dependencies using the lockfile and settings
# Use separate cache mount and clean up after installation to save space
RUN --mount=type=cache,target=/root/.cache/uv,sharing=locked \
    uv sync --locked --no-dev && \
    # Clean up unnecessary files to save space
    find /workspace/.venv -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true && \
    find /workspace/.venv -type f -name "*.pyc" -delete 2>/dev/null || true && \
    find /workspace/.venv -type f -name "*.pyo" -delete 2>/dev/null || true

# Place executables in the environment at the front of the path
ENV PATH="/workspace/.venv/bin:$PATH"

ENTRYPOINT ["/workspace/bin/entrypoint.sh"]
CMD ["/bin/bash"]
