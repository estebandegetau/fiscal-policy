# Research Container Template
# Base: rocker/r-ver:4.5 with Python 3.12, Quarto, TinyTeX, and Claude Code

FROM rocker/r-ver:4.5

LABEL maintainer="Your Name <your.email@example.com>"
LABEL description="Reproducible research container with R 4.5, Python 3.12, Quarto, and targets"

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV RENV_PATHS_CACHE=/renv/cache
ENV RENV_CONFIG_REPOS_OVERRIDE=https://packagemanager.posit.co/cran/latest

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Git and version control
    git \
    git-lfs \
    # Python 3.12 (default in Ubuntu 24.04)
    python3 \
    python3-venv \
    python3-dev \
    python3-pip \
    # Build tools for R packages
    build-essential \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libfribidi-dev \
    libharfbuzz-dev \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    libicu-dev \
    libgit2-dev \
    libssh2-1-dev \
    zlib1g-dev \
    # For targets and quarto
    pandoc \
    # Node.js for Claude Code
    curl \
    ca-certificates \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Set up Python symlink
RUN ln -sf /usr/bin/python3 /usr/bin/python

# Install Python packages
RUN pip3 install --no-cache-dir --break-system-packages \
    numpy \
    pandas \
    jupyter

# Install Quarto (latest stable)
RUN curl -LO https://quarto.org/download/latest/quarto-linux-amd64.deb \
    && dpkg -i quarto-linux-amd64.deb \
    && rm quarto-linux-amd64.deb

# Install TinyTeX for PDF output
RUN quarto install tinytex --update-path

# Install Node.js (LTS) for Claude Code
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code globally
RUN npm install -g @anthropic-ai/claude-code

# Create renv cache directory
RUN mkdir -p ${RENV_PATHS_CACHE}

# Install renv and core R packages
RUN R -e "install.packages(c('renv', 'tidyverse', 'targets', 'tarchetypes', 'here', 'quarto'), repos = 'https://packagemanager.posit.co/cran/latest')"

# Set working directory
WORKDIR /workspace

# Copy project files
COPY . .

# Initialize renv and create lockfile from installed packages
RUN R -e "renv::init(bare = TRUE)" \
    && R -e "renv::snapshot()"

# Default command
CMD ["R"]
