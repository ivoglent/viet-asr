## Build
docker build -f Dockerfile -t vietstt:1.0.0-dev .
docker build -f Dockerfile-optimized -t vietstt:1.0.0-dev-2 .

## Run test
docker run --rm -it --mount type=bind,source="$(pwd)"/app.py,target=/home/root/speech2text/viet-asr/app.py,readonly vietstt:1.0.0-dev bash