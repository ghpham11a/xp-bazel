// ProgramTest.cs — Plain C# test (no xunit, no NuGet dependencies).
//
// WHY NO XUNIT?
// rules_dotnet's csharp_test generates a .deps.json manifest that expects
// NuGet DLLs at specific runfiles paths. On Windows with Bazel 9, these
// paths don't match the actual output layout, causing runtime errors like:
//
//   "An assembly specified in the application dependencies manifest was not found"
//
// This is a known limitation of rules_dotnet's NuGet integration on Windows.
// Until it's fixed upstream, we use a plain executable that:
//   - Runs assertions manually
//   - Returns exit code 0 (pass) or 1 (fail)
//   - Bazel interprets exit code to determine test result
//
// This is actually how Bazel's test contract works at its core — a test is
// just a program that returns 0 or non-zero. xunit, gtest, pytest, etc. are
// all just wrappers around this simple contract.

using System;

public class ProgramTest
{
    static int failures = 0;

    static void AssertEqual(string expected, string actual, string testName)
    {
        if (expected == actual)
        {
            Console.WriteLine($"  PASS: {testName}");
        }
        else
        {
            Console.Error.WriteLine($"  FAIL: {testName}");
            Console.Error.WriteLine($"        Expected: \"{expected}\"");
            Console.Error.WriteLine($"        Actual:   \"{actual}\"");
            failures++;
        }
    }

    public static int Main(string[] args)
    {
        Console.WriteLine("Running C# tests...\n");

        // Test each subtask's GetMessage() method
        AssertEqual(
            "Subtask A complete from C#",
            SubtaskA.GetMessage(),
            "SubtaskA.GetMessage returns expected message"
        );

        AssertEqual(
            "Subtask B complete from C#",
            SubtaskB.GetMessage(),
            "SubtaskB.GetMessage returns expected message"
        );

        // NOTE: We don't test Program.GetMessage() here because Program.cs
        // has its own Main() method which would conflict with this file's Main().
        // To test Program too, you'd need to extract GetMessage() into a
        // separate class or use a csharp_library dep (once the deps.json issue
        // is resolved upstream in rules_dotnet).

        int total = 2;
        Console.WriteLine($"\nResults: {total - failures} passed, {failures} failed, {total} total");
        return failures > 0 ? 1 : 0;
    }
}
