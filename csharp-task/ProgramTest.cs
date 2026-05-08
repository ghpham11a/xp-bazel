using System;
using Xunit;

public class ProgramTest
{
    [Fact]
    public void TestGetMessage()
    {
        Assert.Equal("Task complete from C#", Program.GetMessage());
    }
}
