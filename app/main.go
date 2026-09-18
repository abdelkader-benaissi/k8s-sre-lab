package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

var memoryPressure []byte

type dependency interface {
	Check(context.Context) error
	Operate(context.Context) error
	Close()
}

type externalDependencies struct {
	database *pgxpool.Pool
	cache    *redis.Client
}

func newExternalDependencies(ctx context.Context) (*externalDependencies, error) {
	database, err := pgxpool.New(ctx, requiredEnv("DATABASE_URL"))
	if err != nil {
		return nil, fmt.Errorf("configure database: %w", err)
	}
	options, err := redis.ParseURL(requiredEnv("REDIS_URL"))
	if err != nil {
		database.Close()
		return nil, fmt.Errorf("configure redis: %w", err)
	}
	return &externalDependencies{database: database, cache: redis.NewClient(options)}, nil
}

func (d *externalDependencies) Check(ctx context.Context) error {
	if err := d.database.Ping(ctx); err != nil {
		return fmt.Errorf("database: %w", err)
	}
	if err := d.cache.Ping(ctx).Err(); err != nil {
		return fmt.Errorf("redis: %w", err)
	}
	return nil
}

func (d *externalDependencies) Operate(ctx context.Context) error {
	var one int
	if err := d.database.QueryRow(ctx, "select 1").Scan(&one); err != nil {
		return fmt.Errorf("database operation: %w", err)
	}
	if one != 1 {
		return errors.New("database operation returned an invalid result")
	}
	if err := d.cache.Incr(ctx, "sre:successful_requests").Err(); err != nil {
		return fmt.Errorf("redis operation: %w", err)
	}
	return nil
}

func (d *externalDependencies) Close() {
	d.database.Close()
	_ = d.cache.Close()
}

type metrics struct {
	sync.Mutex
	requests map[string]uint64
	buckets  []float64
	counts   []uint64
	count    uint64
	sum      float64
}

func newMetrics() *metrics {
	buckets := []float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5}
	return &metrics{requests: map[string]uint64{}, buckets: buckets, counts: make([]uint64, len(buckets))}
}

func (m *metrics) observe(code int, duration time.Duration) {
	m.Lock()
	defer m.Unlock()
	m.requests[strconv.Itoa(code)]++
	seconds := duration.Seconds()
	m.count++
	m.sum += seconds
	for index, boundary := range m.buckets {
		if seconds <= boundary {
			m.counts[index]++
		}
	}
}

func (m *metrics) serveHTTP(w http.ResponseWriter, _ *http.Request) {
	m.Lock()
	defer m.Unlock()
	w.Header().Set("Content-Type", "text/plain; version=0.0.4")
	for code, count := range m.requests {
		fmt.Fprintf(w, "http_requests_total{code=%q} %d\n", code, count)
	}
	for index, boundary := range m.buckets {
		fmt.Fprintf(w, "http_request_duration_seconds_bucket{le=%q} %d\n", strconv.FormatFloat(boundary, 'g', -1, 64), m.counts[index])
	}
	fmt.Fprintf(w, "http_request_duration_seconds_bucket{le=\"+Inf\"} %d\n", m.count)
	fmt.Fprintf(w, "http_request_duration_seconds_sum %g\n", m.sum)
	fmt.Fprintf(w, "http_request_duration_seconds_count %d\n", m.count)
}

func newHandler(dependencies dependency, measurements *metrics) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", func(w http.ResponseWriter, r *http.Request) {
		started := time.Now()
		status := http.StatusOK
		defer func() { measurements.observe(status, time.Since(started)) }()

		if delay, err := time.ParseDuration(r.URL.Query().Get("delay")); err == nil && delay > 0 {
			time.Sleep(delay)
		}
		if r.URL.Query().Get("fail") == "true" {
			status = http.StatusInternalServerError
			http.Error(w, "injected failure", status)
			return
		}
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()
		if err := dependencies.Operate(ctx); err != nil {
			status = http.StatusServiceUnavailable
			http.Error(w, "dependency unavailable", status)
			return
		}
		fmt.Fprintln(w, "ok")
	})
	mux.HandleFunc("GET /health/live", ok)
	mux.HandleFunc("GET /health/startup", ok)
	mux.HandleFunc("GET /health/ready", func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), time.Second)
		defer cancel()
		if err := dependencies.Check(ctx); err != nil {
			http.Error(w, err.Error(), http.StatusServiceUnavailable)
			return
		}
		ok(w, r)
	})
	mux.HandleFunc("GET /metrics", measurements.serveHTTP)
	return mux
}

func main() {
	if mb, _ := strconv.Atoi(os.Getenv("ALLOCATE_MB")); mb > 0 {
		memoryPressure = make([]byte, mb*1024*1024)
		for index := range memoryPressure {
			memoryPressure[index] = 1
		}
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	dependencies, err := newExternalDependencies(ctx)
	if err != nil {
		log.Fatal(err)
	}
	defer dependencies.Close()

	server := &http.Server{
		Addr:              ":8080",
		Handler:           newHandler(dependencies, newMetrics()),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}
	go func() {
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Printf("server error: %v", err)
			stop()
		}
	}()
	<-ctx.Done()
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := server.Shutdown(shutdownCtx); err != nil {
		log.Printf("shutdown error: %v", err)
	}
}

func ok(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = fmt.Fprintln(w, "ok")
}

func requiredEnv(key string) string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		log.Fatalf("%s is required", key)
	}
	return value
}
