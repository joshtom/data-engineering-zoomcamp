# Start with slim Python 3.13 image (USING UV)
FROM python:3.13.10-slim

# Copy uv binary from official uv image (multi-stage build pattern)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/

# Set working directory
WORKDIR /app

# Add virtual environment to PATH so we can use installed packages
ENV PATH="/app/.venv/bin:$PATH"

# Copy dependency files first (better layer caching)
COPY "pyproject.toml" "uv.lock" ".python-version" ./
# Install dependencies from lock file (ensures reproducible builds)
RUN uv sync --locked

# Copy application code
COPY pipeline.py pipeline.py

# Set entry point
ENTRYPOINT ["python", "pipeline.py"]

# USING PIP 
# base Docker image that we will build on
# FROM python:3.13.11-slim

# # set up our image by installing prerequisites; pandas in this case
# RUN pip install pandas pyarrow

# # set up the working directory inside the container
# WORKDIR /app
# # copy the script to the container. 1st name is source file, 2nd is destination
# COPY pipeline.py pipeline.py

# # define what to do first when the container runs
# # in this example, we will just run the script
# ENTRYPOINT ["python", "pipeline.py"]

