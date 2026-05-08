package main

import "testing"

func TestGetMessage(t *testing.T) {
	expected := "Task complete from Go"
	actual := getMessage()
	if actual != expected {
		t.Errorf("expected %q, got %q", expected, actual)
	}
}
