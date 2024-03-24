package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var start = time.Now()
var readinessDelayFlag = flag.Int("delay-ready", 0, "Seconds after start to report ready=false")

var httpRequestsTotal = prometheus.NewCounter(
	prometheus.CounterOpts{
		Name: "http_requests_total",
		Help: "Total number of http requests.",
	},
)

func handler(w http.ResponseWriter, r *http.Request) {
	httpRequestsTotal.Inc()
	msg := "Received a request"
	fmt.Fprint(w, msg)
	log.Println(msg)
}

func readiness(w http.ResponseWriter, r *http.Request) {
	httpRequestsTotal.Inc()
	duration := time.Since(start)
	msg := fmt.Sprintf("Received a readiness request after %s", duration)
	var readinessAfter = time.Second * time.Duration(*readinessDelayFlag)
	log.Printf("readinessAfter: %s", readinessAfter)
	if duration < readinessAfter {
		w.WriteHeader(400)
		msg = msg + " - unready"
	} else {
		w.WriteHeader(200)
		msg = msg + " - ready"
	}
	fmt.Fprint(w, msg+"\n")
	log.Println(msg)
}

func main() {
	port := "8080"
	start = time.Now()
	flag.Parse()
	log.Printf("Delayflag: %d", *readinessDelayFlag)
	prometheus.MustRegister(httpRequestsTotal)
	http.HandleFunc("/readyz", readiness)
	http.HandleFunc("/", handler)
	http.Handle("/metrics", promhttp.Handler())
	log.Printf("Server started on port %v", port)
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%v", port), nil))
}
