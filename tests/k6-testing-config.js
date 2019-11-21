import http from "k6/http";

export let options = {
	insecureSkipTLSVerify: true,
	noConnectionReuse: true,
	noVUConnectionReuse: true,
};

export default function() {
	http.get(`https://${__ENV.HELLONGINX_SERVICE_HOST}:9000`);
}
