public class Main {
    public static String getMessage() {
        return "Task complete from Java";
    }

    public static void main(String[] args) {
        System.out.println(SubtaskA.getMessage());
        System.out.println(SubtaskB.getMessage());
        System.out.println(getMessage());
    }
}
