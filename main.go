package main

import (
	"log"
	"net/http"
)

func main() {
	fs := http.FileServer(http.Dir("./public"))
	http.Handle("/", fs)

	addr := ":8080"
	log.Printf("Unseen Hunger Go server running on http://localhost%s", addr)
	log.Fatal(http.ListenAndServe(addr, nil))
}
