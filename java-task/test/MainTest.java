import static org.junit.Assert.assertEquals;
import org.junit.Test;

public class MainTest {
    @Test
    public void testGetMessage() {
        assertEquals("Task complete from Java", Main.getMessage());
    }
}
