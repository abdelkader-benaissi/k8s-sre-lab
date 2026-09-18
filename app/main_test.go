package main

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

type fakeDependency struct {
	checkErr   error
	operateErr error
}

func (f fakeDependency) Check(context.Context) error   { return f.checkErr }
func (f fakeDependency) Operate(context.Context) error { return f.operateErr }
func (f fakeDependency) Close()                        {}

func request(t *testing.T, handler http.Handler, target string) *httptest.ResponseRecorder {
	t.Helper()
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, target, nil))
	return recorder
}

func TestUnknownPathIsNotHealthy(t *testing.T) {
	recorder := request(t, newHandler(fakeDependency{}, newMetrics()), "/does-not-exist")
	if recorder.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", recorder.Code)
	}
}

func TestInjectedFailureAndMetrics(t *testing.T) {
	handler := newHandler(fakeDependency{}, newMetrics())
	if recorder := request(t, handler, "/?fail=true"); recorder.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500, got %d", recorder.Code)
	}
	metricsRecorder := request(t, handler, "/metrics")
	if !strings.Contains(metricsRecorder.Body.String(), `http_requests_total{code="500"} 1`) {
		t.Fatalf("missing failure counter: %s", metricsRecorder.Body.String())
	}
}

func TestDependencyFailureControlsReadinessAndTraffic(t *testing.T) {
	handler := newHandler(fakeDependency{checkErr: errors.New("cache unavailable"), operateErr: errors.New("database unavailable")}, newMetrics())
	if recorder := request(t, handler, "/health/ready"); recorder.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected readiness 503, got %d", recorder.Code)
	}
	if recorder := request(t, handler, "/"); recorder.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected request 503, got %d", recorder.Code)
	}
}
