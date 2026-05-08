"""A deliberately flaky test to demonstrate Bazel's flaky test handling."""
import random
import unittest


class TestFlaky(unittest.TestCase):
    def test_coin_flip(self):
        """Passes ~50% of the time."""
        self.assertTrue(random.random() > 0.5, "Unlucky flip!")


if __name__ == "__main__":
    unittest.main()
