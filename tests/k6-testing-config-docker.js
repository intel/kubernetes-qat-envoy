import http from "k6/http";

export let options = {
	insecureSkipTLSVerify: true,
	noConnectionReuse: true,
	noVUConnectionReuse: true,
};

export default function() {
	http.get("https://localhost:9000/");
}
