envoy-qat:
	docker image build -t envoy-qat:devel -f Dockerfile.envoy . --no-cache

envoy-qat-clr:
	docker image build -t envoy-qat:clr -f Dockerfile.clr.envoy . --no-cache

envoy-boringssl-qat:
	docker image build -t envoy-boringssl-qat:devel -f Dockerfile-boringssl-envoy .  --no-cache

k6-loadimpact:
	cd ./k6 && docker image build -t loadimpact/k6:custom -f Dockerfile . --no-cache
