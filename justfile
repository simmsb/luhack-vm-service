app_name := `grep 'app:' mix.exs | sed -e 's/\[//g' -e 's/ //g' -e 's/app://' -e 's/[:,]//g'`
app_vsn := `grep 'version:' mix.exs | cut -d '"' -f2`
build := `git rev-parse --short HEAD`

# Build the Docker image
build:
  docker build --build-arg APP_VSN={{app_vsn}} \
    -t {{app_name}}:{{app_vsn}}-{{build}} \
    -t {{app_name}}:latest .

# Run the app in Docker
run: 
  docker run -e SECRET_KEY_BASE={{env_var("SECRET_KEY_BASE")}} \
    --expose 4000 -p 4000:4000 \
    --rm -it {{app_name}}:latest

# Push to docker hub
release: 
  docker tag {{app_name}}:latest ghcr.io/simmsb/luhack-vm-service:latest
  docker tag {{app_name}}:{{app_vsn}}-{{build}} ghcr.io/simmsb/luhack-vm-service:{{app_vsn}}-{{build}}
  docker push ghcr.io/lancaster-university/luhack-vm-service 
  docker push ghcr.io/simmsb/luhack-vm-service
