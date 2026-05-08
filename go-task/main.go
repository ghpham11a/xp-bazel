package main

import (
	"fmt"

	subtaska "xp_bazel/go-task/subtask-a"
	subtaskb "xp_bazel/go-task/subtask-b"
)

func getMessage() string {
	return "Task complete from Go"
}

func main() {
	fmt.Println(subtaska.GetMessage())
	fmt.Println(subtaskb.GetMessage())
	fmt.Println(getMessage())
}
