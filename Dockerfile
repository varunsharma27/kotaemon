# Lite version
FROM python:3.10-slim AS lite

# Common dependencies
RUN apt-get update -qqy && \
    apt-get install -y --no-install-recommends \
        ssh \
        git \
        gcc \
        g++ \
        poppler-utils \
        libpoppler-dev \
        unzip \
        curl \
        cargo

# Setup args
ARG TARGETPLATFORM
ARG TARGETARCH

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PYTHONIOENCODING=UTF-8
ENV TARGETARCH=${TARGETARCH}

# Octostar ENV variables:
ENV GRADIO_SERVER_NAME=0.0.0.0
ENV GRADIO_SERVER_PORT=8080
ENV GRADIO_ROOT_PATH=/apps/ask-a-question-rag
ENV NanoGraphRAG=true
ENV OCT_DEMO_MODE=true
ENV KH_APP_NAME="Octostar AI"
ENV KH_FEATURE_USER_MANAGEMENT=false

# Create working directory
WORKDIR /app

# Download pdfjs
COPY scripts/download_pdfjs.sh /app/scripts/download_pdfjs.sh
RUN chmod +x /app/scripts/download_pdfjs.sh
ENV PDFJS_PREBUILT_DIR="/app/libs/ktem/ktem/assets/prebuilt/pdfjs-dist"
RUN bash scripts/download_pdfjs.sh $PDFJS_PREBUILT_DIR

# Copy contents
COPY . /app
COPY .env.example /app/.env

# Install pip packages
RUN --mount=type=ssh  \
    --mount=type=cache,target=/root/.cache/pip  \
    pip install -e "libs/kotaemon" \
    && pip install -e "libs/ktem" \
    && pip install "pdfservices-sdk@git+https://github.com/niallcm/pdfservices-python-sdk.git@bump-and-unfreeze-requirements"

RUN --mount=type=ssh  \
    --mount=type=cache,target=/root/.cache/pip  \
    if [ "$TARGETARCH" = "amd64" ]; then pip install "graphrag<=0.3.6" future; fi

# Clean up
RUN apt-get autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf ~/.cache

CMD ["python", "app.py"]

# Full version
FROM lite AS full

# Additional dependencies for full version
RUN apt-get update -qqy && \
    apt-get install -y --no-install-recommends \
        tesseract-ocr \
        tesseract-ocr-jpn \
        libsm6 \
        libxext6 \
        libreoffice \
        ffmpeg \
        libmagic-dev

# Install torch and torchvision for unstructured
RUN --mount=type=ssh  \
    --mount=type=cache,target=/root/.cache/pip  \
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Install additional pip packages
RUN --mount=type=ssh  \
    --mount=type=cache,target=/root/.cache/pip  \
    pip install -e "libs/kotaemon[adv]" \
    && pip install unstructured[all-docs]

# Install lightRAG
ENV USE_LIGHTRAG=true
RUN --mount=type=ssh  \
    --mount=type=cache,target=/root/.cache/pip  \
    pip install aioboto3 nano-vectordb ollama xxhash "lightrag-hku<=0.0.8"

RUN --mount=type=ssh  \
    --mount=type=cache,target=/root/.cache/pip  \
    pip install "docling<=2.5.2"

# Clean up
RUN apt-get autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf ~/.cache


# Copy NLTK data into the Docker image
COPY nltk_data /usr/local/nltk_data

# Set the NLTK_DATA environment variable
ENV NLTK_DATA=/usr/local/nltk_data

RUN pip install nano-graphrag
# To be able to test images locally. It's re-installed in env via main.sh
RUN pip install https://home.dev.octostar.com/api/octostar/meta/octostar-python-client.tar.gz
RUN pip uninstall -y hnswlib chroma-hnswlib && pip install chroma-hnswlib

EXPOSE 8080

# Download nltk packages as required for unstructured
# RUN python -c "from unstructured.nlp.tokenize import _download_nltk_packages_if_not_present; _download_nltk_packages_if_not_present()"

CMD ["python", "app.py"]
