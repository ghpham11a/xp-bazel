"""Test that loads expected messages from a fixture file using runfiles."""
import json
import unittest

from python.runfiles import runfiles

from subtask_a.subtask_a import get_message as get_a
from subtask_b.subtask_b import get_message as get_b


class TestFixture(unittest.TestCase):
    def setUp(self):
        r = runfiles.Create()
        path = r.Rlocation("xp_bazel/python-task/testdata/expected_messages.json")
        with open(path) as f:
            self.expected = json.load(f)

    def test_subtask_a_matches_fixture(self):
        self.assertEqual(get_a(), self.expected["subtask_a"])

    def test_subtask_b_matches_fixture(self):
        self.assertEqual(get_b(), self.expected["subtask_b"])


if __name__ == "__main__":
    unittest.main()
