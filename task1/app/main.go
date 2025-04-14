package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
)

type LogMessage struct {
	Message string `json:"message"`
}

type Config struct {
	LogLevel     string `json:"log_level"`
	Port         string `json:"port"`
	WelcomeText  string `json:"welcome_text"`
	LogDirectory string `json:"log_directory"`
}

var config Config

func init() {
	config = Config{
		LogLevel:     "info",
		Port:         "8080",
		WelcomeText:  "Welcome to the custom app",
		LogDirectory: "/app/logs",
	}

	if err := os.MkdirAll(config.LogDirectory, 0755); err != nil {
		log.Fatalf("Failed to create log directory: %v", err)
	}
}

func welcomeHandler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, config.WelcomeText)
}

func statusHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func logHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var logMsg LogMessage
	if err := json.NewDecoder(r.Body).Decode(&logMsg); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	logFile := filepath.Join(config.LogDirectory, "app.log")
	f, err := os.OpenFile(logFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		http.Error(w, "Failed to open log file", http.StatusInternalServerError)
		return
	}
	defer f.Close()

	if _, err := f.WriteString(logMsg.Message + "\n"); err != nil {
		http.Error(w, "Failed to write log", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
}

func logsHandler(w http.ResponseWriter, r *http.Request) {
	logFile := filepath.Join(config.LogDirectory, "app.log")
	content, err := os.ReadFile(logFile)
	if err != nil {
		http.Error(w, "Failed to read logs", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/plain")
	w.Write(content)
}

func main() {
	http.HandleFunc("/", welcomeHandler)
	http.HandleFunc("/status", statusHandler)
	http.HandleFunc("/log", logHandler)
	http.HandleFunc("/logs", logsHandler)

	log.Printf("Server starting on port %s", config.Port)
	if err := http.ListenAndServe(":"+config.Port, nil); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}
