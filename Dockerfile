ARG framework_release
ARG framework_build

#Base
FROM $framework_release AS base
WORKDIR /app
EXPOSE 80

#Build
FROM $framework_build AS build
ARG version_suffix
ARG project_path

# Build the app
WORKDIR /sln
COPY . .
RUN rm -f global.json
RUN dotnet publish  $project_path --version-suffix=${version_suffix}  -c Release -o /app

#Finalize container
FROM base AS final
ARG docker_entrypoint
ENV env_docker_entrypoint=$docker_entrypoint

ARG api_key
ARG service_name
ARG env

#Datadog variables
ENV DD_ENV=$env
ENV DD_SERVICE=$service_name
ENV DD_VERSION=$version_suffix
ENV DD_API_KEY=$api_key

ENV DD_LOGS_ENABLED=true
ENV DD_LOGS_INJECTION=true
ENV DD_RUNTIME_METRICS_ENABLED=true

#Datadog serverless for dotnet
COPY --from=datadog/serverless-init:1 /datadog-init /app/datadog-init
COPY --from=datadog/dd-lib-dotnet-init /datadog-init/monitoring-home/ /dd_tracer/dotnet/

#Start app
WORKDIR /app
COPY --from=build /app .

ENTRYPOINT ["/app/datadog-init"]
CMD dotnet $env_docker_entrypoint
