import unittest
from main import get_message


class TestMain(unittest.TestCase):
    def test_get_message(self):
        self.assertEqual(get_message(), "Task complete from Python")


if __name__ == "__main__":
    unittest.main()
