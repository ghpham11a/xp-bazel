import unittest
from subtask_b.subtask_b import get_message


class TestSubtaskB(unittest.TestCase):
    def test_get_message(self):
        self.assertEqual(get_message(), "Subtask B complete from Python")

    def test_get_message_type(self):
        self.assertIsInstance(get_message(), str)


if __name__ == "__main__":
    unittest.main()
