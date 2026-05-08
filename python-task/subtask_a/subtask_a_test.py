import unittest
from subtask_a.subtask_a import get_message


class TestSubtaskA(unittest.TestCase):
    def test_get_message(self):
        self.assertEqual(get_message(), "Subtask A complete from Python")

    def test_get_message_type(self):
        self.assertIsInstance(get_message(), str)


if __name__ == "__main__":
    unittest.main()
