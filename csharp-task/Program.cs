using System;

public class Program
{
    public static string GetMessage()
    {
        return "Task complete from C#";
    }

    public static void Main(string[] args)
    {
        Console.WriteLine(SubtaskA.GetMessage());
        Console.WriteLine(SubtaskB.GetMessage());
        Console.WriteLine(GetMessage());
    }
}
