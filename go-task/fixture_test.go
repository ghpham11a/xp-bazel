package main

import (
	"encoding/json"
	"os"
	"testing"

	"github.com/bazelbuild/rules_go/go/runfiles"
	subtaska "xp_bazel/go-task/subtask-a"
	subtaskb "xp_bazel/go-task/subtask-b"
)

func TestFixture(t *testing.T) {
	path, err := runfiles.Rlocation("xp_bazel/go-task/testdata/expected_messages.json")
	if err != nil {
		t.Fatalf("failed to find runfile: %v", err)
	}

	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("failed to read fixture: %v", err)
	}

	var expected map[string]string
	if err := json.Unmarshal(data, &expected); err != nil {
		t.Fatalf("failed to parse fixture: %v", err)
	}

	if got := subtaska.GetMessage(); got != expected["subtask_a"] {
		t.Errorf("subtask_a: expected %q, got %q", expected["subtask_a"], got)
	}

	if got := subtaskb.GetMessage(); got != expected["subtask_b"] {
		t.Errorf("subtask_b: expected %q, got %q", expected["subtask_b"], got)
	}
}
