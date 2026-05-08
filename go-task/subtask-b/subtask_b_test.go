package subtaskb

import "testing"

func TestGetMessage(t *testing.T) {
	expected := "Subtask B complete from Go"
	actual := GetMessage()
	if actual != expected {
		t.Errorf("expected %q, got %q", expected, actual)
	}
}

func TestGetMessageNotEmpty(t *testing.T) {
	if GetMessage() == "" {
		t.Error("expected non-empty message")
	}
}
